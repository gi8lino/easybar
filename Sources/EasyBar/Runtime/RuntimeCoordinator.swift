import EasyBarShared
import Foundation

/// Actor-owned runtime coordinator.
///
/// This is the single owner of startup, shutdown, reload, file watching,
/// socket command handling, and runtime refresh orchestration.
actor RuntimeCoordinator {
  private let logger: ProcessLogger
  private let configManager = ConfigManager.shared
  private let fileWatcher: FileWatcher
  private let luaRuntime: LuaRuntime
  private let widgetEngine: WidgetEngine

  private let aeroSpaceService = AeroSpaceService.shared
  private let socketServer: SocketServer
  private let metricsCoordinator = MetricsCoordinator.shared

  private var watcherTask: Task<Void, Never>?
  private var started = false
  private var lifecycleGeneration: UInt64 = 0
  private var isReloadingConfig = false
  private var isRestartingLuaRuntime = false
  private var queuedConfigReload = false
  private var queuedLuaRuntimeRestart = false

  /// Creates one runtime coordinator.
  init(logger: ProcessLogger) {
    self.logger = logger
    self.fileWatcher = FileWatcher(logger: logger)
    luaRuntime = LuaRuntime.shared

    widgetEngine = WidgetEngine(
      logger: logger,
      luaRuntime: luaRuntime
    )

    socketServer = SocketServer(logger: logger)
  }

  /// Starts the actor-owned runtime.
  func start() async {
    guard !started else { return }
    started = true
    lifecycleGeneration &+= 1

    logger.info("runtime coordinator start begin")

    await configureLogging()

    await MainActor.run {
      NativeWidgetRegistry.shared.start()
    }

    CalendarAgentEventRelay.shared.start()
    await widgetEngine.start()
    aeroSpaceService.start()

    await startFileWatcher()
    startSocketServer()

    logger.info("runtime coordinator start end")
  }

  /// Stops the actor-owned runtime.
  func stop() async {
    guard started else { return }
    started = false
    lifecycleGeneration &+= 1

    logger.info("runtime coordinator stop begin")

    isReloadingConfig = false
    isRestartingLuaRuntime = false
    queuedConfigReload = false
    queuedLuaRuntimeRestart = false

    watcherTask?.cancel()
    watcherTask = nil

    await fileWatcher.stop()

    metricsCoordinator.onSnapshot = nil
    socketServer.stop()
    aeroSpaceService.stop()
    CalendarAgentEventRelay.shared.stop()

    await widgetEngine.shutdown()

    await MainActor.run {
      NativeWidgetRegistry.shared.stop()
    }

    logger.info("runtime coordinator stop end")
  }

  /// Reloads config and reapplies all dependent runtime state.
  func reloadConfig() async {
    if isReloadingConfig || isRestartingLuaRuntime {
      queuedConfigReload = true
      logger.info("reloadConfig busy; queueing another reload")
      return
    }

    let generation = lifecycleGeneration
    isReloadingConfig = true
    logger.info("reloadConfig begin")

    let result = await configManager.reload()
    guard shouldContinueLifecycleWork(generation: generation, operation: "reloadConfig") else {
      return
    }

    await configureLogging()
    guard shouldContinueLifecycleWork(generation: generation, operation: "reloadConfig") else {
      return
    }

    await widgetEngine.reload()
    guard shouldContinueLifecycleWork(generation: generation, operation: "reloadConfig") else {
      return
    }

    await MainActor.run {
      NativeWidgetRegistry.shared.reload()
    }
    guard shouldContinueLifecycleWork(generation: generation, operation: "reloadConfig") else {
      return
    }

    await restartFileWatcher()
    guard shouldContinueLifecycleWork(generation: generation, operation: "reloadConfig") else {
      return
    }

    await reloadSocketServerConfiguration()

    aeroSpaceService.triggerRefresh()

    if let errorMessage = result.errorMessage {
      logger.warn("config reload completed with error=\(errorMessage)")
    }

    logger.info("reloadConfig end")
    isReloadingConfig = false

    if queuedConfigReload {
      queuedConfigReload = false
      await reloadConfig()
      return
    }

    if queuedLuaRuntimeRestart {
      queuedLuaRuntimeRestart = false
      await restartLuaRuntime()
    }
  }

  /// Restarts the Lua/widget runtime and reapplies native widgets afterward.
  func restartLuaRuntime() async {
    if isReloadingConfig || isRestartingLuaRuntime {
      queuedLuaRuntimeRestart = true
      logger.info("restartLuaRuntime busy; queueing another restart")
      return
    }

    let generation = lifecycleGeneration
    isRestartingLuaRuntime = true
    logger.info("restartLuaRuntime begin")

    await widgetEngine.reload()
    guard shouldContinueLifecycleWork(generation: generation, operation: "restartLuaRuntime") else {
      return
    }

    aeroSpaceService.triggerRefresh()

    logger.info("restartLuaRuntime end")
    isRestartingLuaRuntime = false

    if queuedConfigReload {
      queuedConfigReload = false
      await reloadConfig()
      return
    }

    if queuedLuaRuntimeRestart {
      queuedLuaRuntimeRestart = false
      await restartLuaRuntime()
    }
  }

  /// Refreshes the current runtime without reloading config.
  func refreshRuntime() async {
    logger.info("refreshRuntime begin")
    aeroSpaceService.triggerRefresh()
    await EventHub.shared.emit(.manualRefresh)
    logger.info("refreshRuntime end")
  }

  /// Handles one incoming IPC command.
  func handleSocketCommand(_ command: IPC.Command) async {
    logger.info("handleSocketCommand command=\(command)")

    switch command {
    case .workspaceChanged:
      aeroSpaceService.triggerRefresh()
      await EventHub.shared.emit(.workspaceChange)

    case .focusChanged:
      aeroSpaceService.triggerRefresh()
      await EventHub.shared.emit(.focusChange)

    case .spaceModeChanged:
      aeroSpaceService.triggerRefresh()
      await EventHub.shared.emit(.spaceModeChange)

    case .manualRefresh:
      await refreshRuntime()

    case .reloadConfig:
      await reloadConfig()

    case .restartLuaRuntime:
      await restartLuaRuntime()

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
  private func shouldContinueLifecycleWork(generation: UInt64, operation: String) -> Bool {
    guard started, lifecycleGeneration == generation else {
      if lifecycleGeneration == generation {
        isReloadingConfig = false
        isRestartingLuaRuntime = false
      }

      logger.info(
        "\(operation) aborted because runtime stopped or restarted generation=\(generation) current_generation=\(lifecycleGeneration)"
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
