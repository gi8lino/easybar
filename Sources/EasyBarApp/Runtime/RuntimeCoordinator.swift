import EasyBarShared
import Foundation

/// Actor-owned runtime coordinator.
///
/// This remains the orchestration boundary for startup, shutdown, reloads,
/// runtime refreshes, and IPC commands. Lifecycle queue state, config watching,
/// and socket callback bridging are delegated to smaller runtime collaborators.
actor RuntimeCoordinator {
  private let logger: ProcessLogger
  private let services: AppServices
  private let configManager: ConfigManager
  private let configWatcherCoordinator: ConfigWatcherCoordinator
  private let widgetEngine: WidgetEngine
  private let aeroSpaceService: AeroSpaceService
  private let socketCommandAdapter: RuntimeSocketCommandAdapter

  private var lifecycle = RuntimeLifecycleStateMachine()

  init(logger: ProcessLogger, services: AppServices) {
    self.logger = logger
    self.services = services
    self.configManager = services.configManager
    self.aeroSpaceService = services.aeroSpaceService
    self.configWatcherCoordinator = ConfigWatcherCoordinator(
      configManager: services.configManager,
      fileWatcher: FileWatcher(logger: logger.child("file_watcher"))
    )

    self.widgetEngine = WidgetEngine(
      logger: logger.child("widget_engine"),
      luaRuntime: services.luaRuntime,
      configManager: services.configManager,
      eventHub: services.eventHub,
      eventManager: services.eventManager,
      widgetStore: services.widgetStore,
      metricsCoordinator: services.metricsCoordinator
    )

    self.socketCommandAdapter = RuntimeSocketCommandAdapter(
      logger: logger.child("socket_server"),
      metricsCoordinator: services.metricsCoordinator
    )
  }

  func start() async {
    let generation: UInt64

    switch lifecycle.start() {
    case .alreadyStarted:
      logger.warn("runtime coordinator already started")
      return
    case .started(let startedGeneration):
      generation = startedGeneration
    }

    logger.info("runtime coordinator start begin")

    await configureLogging()
    guard shouldContinueStartup(generation: generation) else { return }

    let startupSnapshot = await configManager.snapshot()
    guard shouldContinueStartup(generation: generation) else { return }

    await configureLogging()
    guard shouldContinueStartup(generation: generation) else { return }

    await MainActor.run {
      services.applyRuntimeConfiguration(startupSnapshot)
      services.nativeWidgetRegistry.start(snapshot: startupSnapshot)
      aeroSpaceService.start()
    }
    guard shouldContinueStartup(generation: generation) else { return }

    await widgetEngine.start()
    guard shouldContinueStartup(generation: generation) else { return }

    await startConfigWatcher()
    guard shouldContinueStartup(generation: generation) else { return }

    await startSocketServer()

    aeroSpaceService.triggerRefresh()

    logger.info("runtime coordinator start end")
  }

  func stop() async {
    guard lifecycle.stop() else {
      logger.debug("runtime coordinator stop ignored because it is not started")
      return
    }

    logger.info("runtime coordinator stop begin")

    await configWatcherCoordinator.stop()
    await socketCommandAdapter.stop()

    await widgetEngine.shutdown()

    await MainActor.run {
      services.nativeWidgetRegistry.stop()
      aeroSpaceService.stop()
    }

    logger.info("runtime coordinator stop end")
  }

  func reloadConfig() async {
    let operation = RuntimeLifecycleOperation.reloadConfig

    await withLifecycleOperation(
      operation,
      queuedMessage: "\(operation.rawValue) busy; queueing another reload"
    ) { generation in
      let result = await configManager.reload()
      guard shouldContinueLifecycleWork(generation: generation, operation: operation) else {
        return
      }

      guard
        await runConfigReloadSteps(
          result: result,
          generation: generation,
          operation: operation
        )
      else {
        return
      }

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
    }
  }

  private func runConfigReloadSteps(
    result: ConfigManager.ReloadResult,
    generation: UInt64,
    operation: RuntimeLifecycleOperation
  ) async -> Bool {
    guard await runLifecycleStep(generation: generation, operation: operation, configureLogging)
    else {
      return false
    }

    guard
      await runLifecycleStep(
        generation: generation, operation: operation,
        {
          await MainActor.run {
            services.applyRuntimeConfiguration(result.snapshot)
          }
        })
    else {
      return false
    }

    guard await runLifecycleStep(generation: generation, operation: operation, widgetEngine.reload)
    else {
      return false
    }

    guard
      await runLifecycleStep(
        generation: generation, operation: operation,
        {
          await MainActor.run {
            services.nativeWidgetRegistry.reload(snapshot: result.snapshot)
          }
        })
    else {
      return false
    }

    guard
      await runLifecycleStep(generation: generation, operation: operation, restartConfigWatcher)
    else {
      return false
    }

    return await runLifecycleStep(
      generation: generation,
      operation: operation,
      reloadSocketServerConfiguration
    )
  }

  func restartLuaRuntime() async {
    let operation = RuntimeLifecycleOperation.restartLuaRuntime

    await withLifecycleOperation(
      operation,
      queuedMessage: "\(operation.rawValue) busy; queueing another restart"
    ) { generation in
      await widgetEngine.reload()
      guard shouldContinueLifecycleWork(generation: generation, operation: operation) else {
        return
      }

      aeroSpaceService.triggerRefresh()

      logger.info("\(operation.rawValue) end")
    }
  }

  /// Refreshes the current runtime without reloading config.
  func refreshRuntime() async {
    logger.debug("refreshRuntime begin")
    aeroSpaceService.triggerRefresh()
    await services.eventHub.emit(.manualRefresh, source: EventSourceLabel.runtimeManualRefresh)
    logger.debug("refreshRuntime end")
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

    for warning in result.warnings {
      logger.warn(
        "validateConfig warning",
        .field("config_path", result.configPath),
        .field("warning", warning)
      )
    }

    logger.info(
      "validateConfig succeeded",
      .field("config_path", result.configPath),
      .field("warnings", "\(result.warnings.count)")
    )
    return .configValidated(configPath: result.configPath, warnings: result.warnings)
  }

  /// Handles one incoming IPC command.
  func handleSocketCommand(_ command: IPC.Command) async {
    logger.debug(
      "handling socket command",
      .field("command", command),
    )

    switch command {
    case .manualRefresh:
      await refreshRuntime()

    case .workspaceChange:
      aeroSpaceService.triggerRefresh()
      await services.eventHub.emit(.workspaceChange, source: EventSourceLabel.script(command))

    case .focusChange:
      aeroSpaceService.triggerRefresh()
      await services.eventHub.emit(.focusChange, source: EventSourceLabel.script(command))

    case .spaceModeChange:
      aeroSpaceService.triggerRefresh()
      await services.eventHub.emit(.spaceModeChange, source: EventSourceLabel.script(command))

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
  private func startConfigWatcher() async {
    await configWatcherCoordinator.start { [weak self] in
      await self?.reloadConfig()
    }
  }

  /// Restarts the config watcher after a config reload.
  private func restartConfigWatcher() async {
    await configWatcherCoordinator.restart { [weak self] in
      await self?.reloadConfig()
    }
  }

  /// Returns whether one in-flight lifecycle operation is still allowed to mutate runtime state.
  private func shouldContinueLifecycleWork(
    generation: UInt64,
    operation: RuntimeLifecycleOperation
  ) -> Bool {
    let currentGeneration = lifecycle.generation

    guard lifecycle.canContinueLifecycleWork(generation: generation) else {
      logger.debug(
        "\(operation.rawValue) aborted because runtime stopped or restarted",
        .field("generation", "\(generation)"),
        .field("current_generation", "\(currentGeneration)"),
      )
      return false
    }

    return true
  }

  /// Runs one lifecycle step and returns whether subsequent work may continue.
  private func runLifecycleStep(
    generation: UInt64,
    operation: RuntimeLifecycleOperation,
    _ work: () async -> Void
  ) async -> Bool {
    await work()
    return shouldContinueLifecycleWork(generation: generation, operation: operation)
  }

  /// Runs one serialized lifecycle operation and always releases lifecycle ownership.
  private func withLifecycleOperation(
    _ operation: RuntimeLifecycleOperation,
    queuedMessage: String,
    _ work: (UInt64) async -> Void
  ) async {
    let generation: UInt64

    switch lifecycle.begin(operation) {
    case .queued:
      logger.debug(queuedMessage)
      return
    case .started(let startedGeneration):
      generation = startedGeneration
    }

    logger.info("\(operation.rawValue) begin")

    await work(generation)
    await finishLifecycleOperation(operation)
  }

  /// Marks one lifecycle operation finished and runs the next queued operation when present.
  private func finishLifecycleOperation(_ operation: RuntimeLifecycleOperation) async {
    switch lifecycle.finish(operation) {
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
    guard lifecycle.canContinueStartup(generation: generation) else {
      logger.debug(
        "startup aborted because runtime stopped or restarted",
        .field("generation", "\(generation)"),
        .field("current_generation", "\(lifecycle.generation)"),
      )
      return false
    }

    return true
  }

  /// Starts the IPC socket server.
  private func startSocketServer() async {
    let socketPath = await configManager.easyBarSocketPath()
    await socketCommandAdapter.reloadConfiguration(socketPath: socketPath)

    await socketCommandAdapter.start { [weak self] command in
      await self?.handleSocketCommand(command)
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
    await socketCommandAdapter.reloadConfiguration(socketPath: socketPath)
  }
}

extension Notification.Name {
  /// Posted after one config reload attempt finishes and UI should resync.
  static let easyBarConfigReloadDidFinish = Notification.Name("easybar.configReloadDidFinish")
}
