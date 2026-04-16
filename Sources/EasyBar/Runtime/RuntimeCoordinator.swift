import EasyBarShared
import Foundation

/// Actor-owned runtime coordinator.
///
/// This is the single owner of startup, shutdown, reload, file watching,
/// socket command handling, and runtime refresh orchestration.
actor RuntimeCoordinator {
  static let shared = RuntimeCoordinator()

  private let configManager = ConfigManager.shared
  private let fileWatcher = FileWatcher()
  private let widgetEngine = WidgetEngine.shared

  private let aeroSpaceService = AeroSpaceService.shared
  private let socketServer = SocketServer()
  private let metricsCoordinator = MetricsCoordinator.shared

  private var watcherTask: Task<Void, Never>?
  private var started = false
  private var isReloadingConfig = false
  private var isRestartingLuaRuntime = false
  private var queuedConfigReload = false
  private var queuedLuaRuntimeRestart = false

  /// Starts the actor-owned runtime.
  func start() async {
    guard !started else { return }
    started = true

    easybarLog.info("runtime coordinator start begin")

    await configureLogging()

    await MainActor.run {
      NativeWidgetRegistry.shared.start()
    }

    await widgetEngine.start()
    aeroSpaceService.start()

    await startFileWatcher()
    startSocketServer()

    easybarLog.info("runtime coordinator start end")
  }

  /// Stops the actor-owned runtime.
  func stop() async {
    guard started else { return }
    started = false

    easybarLog.info("runtime coordinator stop begin")

    isReloadingConfig = false
    isRestartingLuaRuntime = false
    queuedConfigReload = false
    queuedLuaRuntimeRestart = false

    watcherTask?.cancel()
    watcherTask = nil

    await fileWatcher.stop()

    metricsCoordinator.onSnapshot = nil
    socketServer.stop()

    await widgetEngine.shutdown()

    await MainActor.run {
      NativeWidgetRegistry.shared.stop()
    }

    easybarLog.info("runtime coordinator stop end")
  }

  /// Reloads config and reapplies all dependent runtime state.
  func reloadConfig() async {
    if isReloadingConfig || isRestartingLuaRuntime {
      queuedConfigReload = true
      easybarLog.info("reloadConfig busy; queueing another reload")
      return
    }

    isReloadingConfig = true
    easybarLog.info("reloadConfig begin")

    let result = await configManager.reload()

    await configureLogging()

    await widgetEngine.reload()

    await MainActor.run {
      NativeWidgetRegistry.shared.reload()
      AppController.shared.handlePostConfigReloadUI()
    }

    await restartFileWatcher()
    reloadSocketServerConfiguration()

    aeroSpaceService.triggerRefresh()

    if let errorMessage = result.errorMessage {
      easybarLog.warn("config reload completed with error=\(errorMessage)")
    }

    easybarLog.info("reloadConfig end")
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
      easybarLog.info("restartLuaRuntime busy; queueing another restart")
      return
    }

    isRestartingLuaRuntime = true
    easybarLog.info("restartLuaRuntime begin")

    await widgetEngine.reload()

    await MainActor.run {
      NativeWidgetRegistry.shared.reload()
    }

    aeroSpaceService.triggerRefresh()

    easybarLog.info("restartLuaRuntime end")
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
    easybarLog.info("refreshRuntime begin")
    aeroSpaceService.triggerRefresh()
    await EventHub.shared.emit(.manualRefresh)
    easybarLog.info("refreshRuntime end")
  }

  /// Handles one incoming IPC command.
  func handleSocketCommand(_ command: IPC.Command) async {
    easybarLog.info("handleSocketCommand command=\(command)")

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

    easybarLog.configureRuntimeLogging(
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

  /// Starts the IPC socket server.
  private func startSocketServer() {
    metricsCoordinator.onSnapshot = { [weak self] snapshot in
      Task {
        await self?.broadcastMetrics(snapshot)
      }
    }

    socketServer.start { [weak self] command in
      guard let self else { return }

      Task {
        await self.handleSocketCommand(command)
      }
    }
  }

  /// Rebinds the IPC socket server when the config changed the socket path.
  private func reloadSocketServerConfiguration() {
    socketServer.reloadConfiguration()
  }

  /// Broadcasts one metrics snapshot through the IPC socket server.
  func broadcastMetrics(_ snapshot: IPC.MetricsSnapshot) {
    socketServer.broadcastMetrics(snapshot)
  }
}
