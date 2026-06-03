import EasyBarShared
import Foundation

/// Actor-owned runtime coordinator.
///
/// This is the single owner of startup, shutdown, reload, file watching,
/// socket command handling, and runtime refresh orchestration.
actor RuntimeCoordinator {
  /// Actor-owned lifecycle operations that can be queued while another one is running.
  private enum LifecycleOperation: String {
    case reloadConfig
    case restartLuaRuntime
  }

  /// Mutable runtime lifecycle state used to serialize reload/restart work.
  private struct LifecycleState {
    /// Whether runtime services are currently started.
    var started = false
    /// Generation used to cancel stale lifecycle work.
    var generation: UInt64 = 0
    /// Whether a config reload is in progress.
    var isReloadingConfig = false
    /// Whether a Lua runtime restart is in progress.
    var isRestartingLuaRuntime = false
    /// Whether another config reload should run after current work.
    var queuedConfigReload = false
    /// Whether another Lua restart should run after current work.
    var queuedLuaRuntimeRestart = false

    /// Advances the lifecycle generation and returns the new value.
    mutating func advanceGeneration() -> UInt64 {
      generation &+= 1
      return generation
    }

    /// Returns whether the runtime is currently busy with another lifecycle operation.
    var isBusy: Bool {
      isReloadingConfig || isRestartingLuaRuntime
    }

    /// Queues the provided lifecycle operation.
    mutating func queue(_ operation: LifecycleOperation) {
      switch operation {
      case .reloadConfig:
        queuedConfigReload = true
      case .restartLuaRuntime:
        queuedLuaRuntimeRestart = true
      }
    }

    /// Marks one lifecycle operation as started.
    mutating func begin(_ operation: LifecycleOperation) {
      switch operation {
      case .reloadConfig:
        isReloadingConfig = true
      case .restartLuaRuntime:
        isRestartingLuaRuntime = true
      }
    }

    /// Marks one lifecycle operation as finished.
    mutating func end(_ operation: LifecycleOperation) {
      switch operation {
      case .reloadConfig:
        isReloadingConfig = false
      case .restartLuaRuntime:
        isRestartingLuaRuntime = false
      }
    }

    /// Clears queued and in-flight lifecycle work.
    mutating func resetWork() {
      isReloadingConfig = false
      isRestartingLuaRuntime = false
      queuedConfigReload = false
      queuedLuaRuntimeRestart = false
    }

    /// Dequeues the next pending lifecycle operation in priority order.
    mutating func dequeueNextOperation() -> LifecycleOperation? {
      if queuedConfigReload {
        queuedConfigReload = false
        return .reloadConfig
      }

      if queuedLuaRuntimeRestart {
        queuedLuaRuntimeRestart = false
        return .restartLuaRuntime
      }

      return nil
    }
  }

  /// Logger used for runtime coordination diagnostics.
  private let logger: ProcessLogger
  /// Explicit runtime dependencies resolved by the app shell.
  private let services: AppServices
  /// Actor used for config reloads and runtime config reads.
  private let configManager: ConfigManager
  /// Watches config changes when enabled.
  private let fileWatcher: FileWatcher
  /// Shared Lua runtime process owner.
  private let luaRuntime: LuaRuntime
  /// Coordinates Lua and native widget rendering.
  private let widgetEngine: WidgetEngine

  /// Shared AeroSpace integration service.
  private let aeroSpaceService: AeroSpaceService
  /// IPC server for external commands and metrics.
  private let socketServer: SocketServer
  /// Shared runtime metrics collector.
  private let metricsCoordinator: MetricsCoordinator

  /// Task consuming config watcher events.
  private var watcherTask: Task<Void, Never>?
  /// Mutable runtime lifecycle bookkeeping.
  private var lifecycleState = LifecycleState()

  /// Creates one runtime coordinator.
  init(logger: ProcessLogger, services: AppServices) {
    self.logger = logger
    self.services = services
    self.configManager = services.configManager
    self.fileWatcher = FileWatcher(logger: logger.child("file_watcher"))
    self.metricsCoordinator = services.metricsCoordinator
    luaRuntime = services.luaRuntime
    aeroSpaceService = services.aeroSpaceService

    widgetEngine = WidgetEngine(
      logger: logger.child("widget_engine"),
      luaRuntime: luaRuntime,
      configManager: services.configManager,
      eventHub: services.eventHub,
      eventManager: services.eventManager,
      widgetStore: services.widgetStore,
      metricsCoordinator: services.metricsCoordinator
    )

    socketServer = SocketServer(logger: logger.child("socket_server"))
  }

  /// Starts the runtime and all related services.
  func start() async {
    guard !lifecycleState.started else {
      logger.warn("runtime coordinator already started")
      return
    }

    let generation = lifecycleState.advanceGeneration()
    lifecycleState.started = true
    logger.info("runtime coordinator start begin")

    await configureLogging()
    guard shouldContinueStartup(generation: generation) else { return }

    let loadResult = await configManager.loadInitialConfig()
    if let errorMessage = loadResult.errorMessage {
      logger.warn(
        "initial config load completed with error",
        .field("error", errorMessage),
      )
    }
    guard shouldContinueStartup(generation: generation) else { return }

    await configureLogging()
    guard shouldContinueStartup(generation: generation) else { return }

    await MainActor.run {
      services.nativeWidgetRegistry.start()
    }
    guard shouldContinueStartup(generation: generation) else { return }

    await widgetEngine.start()
    guard shouldContinueStartup(generation: generation) else { return }

    await startFileWatcher()
    guard shouldContinueStartup(generation: generation) else { return }

    startSocketServer()

    aeroSpaceService.triggerRefresh()

    logger.info("runtime coordinator start end")
  }

  /// Stops the runtime and all related services.
  func stop() async {
    guard lifecycleState.started else {
      logger.info("runtime coordinator stop ignored because it is not started")
      return
    }

    logger.info("runtime coordinator stop begin")

    lifecycleState.started = false
    _ = lifecycleState.advanceGeneration()
    lifecycleState.resetWork()

    watcherTask?.cancel()
    watcherTask = nil
    await fileWatcher.stop()

    metricsCoordinator.onSnapshot = nil
    socketServer.stop()

    await widgetEngine.shutdown()

    await MainActor.run {
      services.nativeWidgetRegistry.stop()
    }

    logger.info("runtime coordinator stop end")
  }

  /// Reloads config and reapplies all dependent runtime state.
  func reloadConfig() async {
    let operation = LifecycleOperation.reloadConfig

    if lifecycleState.isBusy {
      lifecycleState.queue(operation)
      logger.info("\(operation.rawValue) busy; queueing another reload")
      return
    }

    let generation = lifecycleState.generation
    lifecycleState.begin(operation)
    logger.info("\(operation.rawValue) begin")

    let result = await configManager.reload()
    guard shouldContinueLifecycleWork(generation: generation, operation: operation) else {
      return
    }

    await configureLogging()
    guard shouldContinueLifecycleWork(generation: generation, operation: operation) else {
      return
    }

    await widgetEngine.reload()
    guard shouldContinueLifecycleWork(generation: generation, operation: operation) else {
      return
    }

    await MainActor.run {
      services.nativeWidgetRegistry.reload()
    }
    guard shouldContinueLifecycleWork(generation: generation, operation: operation) else {
      return
    }

    await restartFileWatcher()
    guard shouldContinueLifecycleWork(generation: generation, operation: operation) else {
      return
    }

    await reloadSocketServerConfiguration()

    aeroSpaceService.triggerRefresh()

    if let errorMessage = result.errorMessage {
      logger.warn(
        "config reload completed with error",
        .field("error", errorMessage),
      )
    }

    await MainActor.run {
      NotificationCenter.default.post(name: .easyBarConfigReloadDidFinish, object: nil)
    }

    logger.info("\(operation.rawValue) end")
    await finishLifecycleOperation(operation)
  }

  /// Restarts the Lua/widget runtime and reapplies native widgets afterward.
  func restartLuaRuntime() async {
    let operation = LifecycleOperation.restartLuaRuntime

    if lifecycleState.isBusy {
      lifecycleState.queue(operation)
      logger.info("\(operation.rawValue) busy; queueing another restart")
      return
    }

    let generation = lifecycleState.generation
    lifecycleState.begin(operation)
    logger.info("\(operation.rawValue) begin")

    await widgetEngine.reload()
    guard shouldContinueLifecycleWork(generation: generation, operation: operation) else {
      return
    }

    aeroSpaceService.triggerRefresh()

    logger.info("\(operation.rawValue) end")
    await finishLifecycleOperation(operation)
  }

  /// Refreshes the current runtime without reloading config.
  func refreshRuntime() async {
    logger.info("refreshRuntime begin")
    aeroSpaceService.triggerRefresh()
    await services.eventHub.emit(.manualRefresh)
    logger.info("refreshRuntime end")
  }

  /// Validates config through the serialized config manager path.
  func validateConfig(configPathOverride: String?) async -> IPC.Message {
    logger.info(
      "validateConfig begin",
      .field("config_path_override", configPathOverride ?? "<default>")
    )

    let result = await configManager.validateConfig(configPathOverride: configPathOverride)

    if let errorMessage = result.errorMessage {
      logger.warn(
        "validateConfig failed",
        .field("config_path", result.configPath),
        .field("error", errorMessage)
      )
      return .rejected(message: errorMessage)
    }

    logger.info(
      "validateConfig succeeded",
      .field("config_path", result.configPath)
    )
    return .configValidated(configPath: result.configPath)
  }

  /// Handles one incoming IPC command.
  func handleSocketCommand(_ command: IPC.Command) async {
    logger.info(
      "handling socket command",
      .field("command", command),
    )

    switch command {
    case .workspaceChanged:
      aeroSpaceService.triggerRefresh()
      await services.eventHub.emit(.workspaceChange)

    case .focusChanged:
      aeroSpaceService.triggerRefresh()
      await services.eventHub.emit(.focusChange)

    case .spaceModeChanged:
      aeroSpaceService.triggerRefresh()
      await services.eventHub.emit(.spaceModeChange)

    case .manualRefresh:
      await refreshRuntime()

    case .reloadConfig:
      await reloadConfig()

    case .restartLuaRuntime:
      await restartLuaRuntime()

    case .validateConfig:
      break

    case .metrics:
      break
    }
  }

  /// Configures runtime logging from the current config.
  private func configureLogging() async {
    let minimumLevel = await configManager.loggingLevel()
    let fileLoggingEnabled = await configManager.loggingEnabled()
    let loggingDirectory = await configManager.loggingDirectory()

    logger.configureRuntimeLogging(
      minimumLevel: minimumLevel,
      fileLoggingEnabled: fileLoggingEnabled,
      fileLoggingPath: easyBarLogPath(in: loggingDirectory)
    )
  }

  /// Starts the config watcher loop.
  private func startFileWatcher() async {
    let path = await configManager.configPath()
    let enabled = await configManager.watchConfigFileEnabled()
    let stream = await fileWatcher.start(configPath: path, enabled: enabled)

    watcherTask?.cancel()

    watcherTask = Task { [weak self] in
      guard let self else { return }

      for await event in stream {
        switch event {
        case .changed:
          await self.reloadConfig()
        }
      }
    }
  }

  /// Restarts the config watcher after a config reload.
  private func restartFileWatcher() async {
    watcherTask?.cancel()
    watcherTask = nil
    await fileWatcher.stop()
    await startFileWatcher()
  }

  /// Returns whether one in-flight lifecycle operation is still allowed to mutate runtime state.
  private func shouldContinueLifecycleWork(
    generation: UInt64,
    operation: LifecycleOperation
  ) -> Bool {
    guard lifecycleState.started, lifecycleState.generation == generation else {
      if lifecycleState.generation == generation {
        lifecycleState.resetWork()
      }

      logger.info(
        "\(operation.rawValue) aborted because runtime stopped or restarted",
        .field("generation", "\(generation)"),
        .field("current_generation", "\(lifecycleState.generation)"),
      )
      return false
    }

    return true
  }

  /// Marks one lifecycle operation finished and runs the next queued operation when present.
  private func finishLifecycleOperation(_ operation: LifecycleOperation) async {
    lifecycleState.end(operation)

    switch lifecycleState.dequeueNextOperation() {
    case .reloadConfig:
      await reloadConfig()
    case .restartLuaRuntime:
      await restartLuaRuntime()
    case nil:
      break
    }
  }

  /// Returns whether startup work can still continue for the provided generation.
  private func shouldContinueStartup(generation: UInt64) -> Bool {
    guard lifecycleState.started, lifecycleState.generation == generation else {
      logger.info(
        "startup aborted because runtime stopped or restarted",
        .field("generation", "\(generation)"),
        .field("current_generation", "\(lifecycleState.generation)"),
      )
      return false
    }

    return true
  }

  /// Starts the IPC socket server.
  private func startSocketServer() {
    metricsCoordinator.onSnapshot = { [weak self] snapshot in
      Task {
        await self?.broadcastMetrics(snapshot)
      }
    }

    socketServer.start { [weak self] (command: IPC.Command) in
      guard let self else { return }

      Task {
        await self.handleSocketCommand(command)
      }
    } validateConfigHandler: { [weak self] configPathOverride in
      guard let self else {
        return .rejected(message: "config validation unavailable")
      }

      return await self.validateConfig(configPathOverride: configPathOverride)
    }
  }

  /// Rebinds the IPC socket server when the config changed the socket path.
  private func reloadSocketServerConfiguration() async {
    let socketPath = await configManager.easyBarSocketPath()
    socketServer.reloadConfiguration(socketPath: socketPath)
  }

  /// Broadcasts one metrics snapshot through the IPC socket server.
  func broadcastMetrics(_ snapshot: IPC.MetricsSnapshot) {
    socketServer.broadcastMetrics(snapshot)
  }
}

extension Notification.Name {
  /// Posted after one config reload attempt finishes and UI should resync.
  static let easyBarConfigReloadDidFinish = Notification.Name("easybar.configReloadDidFinish")
}
