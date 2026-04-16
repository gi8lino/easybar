import AppKit
import EasyBarShared
import Foundation

/// Top-level runtime owner for EasyBar.
///
/// It owns startup, shutdown, config reload orchestration, file watching,
/// runtime refresh, and IPC command handling.
actor RuntimeCoordinator {
  static let shared = RuntimeCoordinator()

  private let configManager = ConfigManager.shared
  private let eventHub = EventHub.shared
  private let fileWatcher = FileWatcher()
  private let widgetEngine = WidgetEngine.shared
  private let luaRuntime = LuaRuntime.shared

  private let aeroSpaceService = AeroSpaceService.shared
  private let socketServer = SocketServer()
  private let metricsCoordinator = MetricsCoordinator.shared

  private var watcherTask: Task<Void, Never>?
  private var isStarted = false
  private var isReloadingConfig = false
  private var queuedConfigReload = false

  /// Starts all runtime services.
  func start() async {
    guard !isStarted else { return }
    isStarted = true

    easybarLog.info("runtime coordinator start begin")

    await configureLogging()
    await MainActor.run {
      NativeWidgetRegistry.shared.start()
    }
    await widgetEngine.start()

    aeroSpaceService.start()
    await startFileWatcher()
    await startSocketServer()

    await eventHub.publish(.started)
    easybarLog.info("runtime coordinator start end")
  }

  /// Stops all runtime services.
  func stop() async {
    guard isStarted else { return }
    isStarted = false

    easybarLog.info("runtime coordinator stop begin")

    watcherTask?.cancel()
    watcherTask = nil

    await fileWatcher.stop()

    metricsCoordinator.onSnapshot = nil
    socketServer.stop()

    await MainActor.run {
      NativeWidgetRegistry.shared.stop()
    }
    await widgetEngine.shutdown()
    await luaRuntime.shutdown()

    await eventHub.publish(.stopped)
    await eventHub.finish()

    easybarLog.info("runtime coordinator stop end")
  }

  /// Reloads config and reapplies all dependent runtime state.
  func reloadConfig() async {
    if isReloadingConfig {
      queuedConfigReload = true
      easybarLog.info("reloadConfig already in progress; queueing another reload")
      return
    }

    isReloadingConfig = true
    easybarLog.info("reloadConfig begin")

    let result = await configManager.reload()

    await configureLogging()

    await MainActor.run {
      NativeWidgetRegistry.shared.reload()
    }

    await widgetEngine.reload()

    await restartFileWatcher()
    aeroSpaceService.triggerRefresh()

    await MainActor.run {
      RuntimeUIBridge.shared.updateConfigErrorWindow()
      RuntimeUIBridge.shared.reloadBarLayout()
    }

    if result.succeeded {
      await eventHub.publish(.configReloaded)
    } else {
      easybarLog.warn("config reload window presented error=\(result.errorMessage ?? "unknown")")
      await eventHub.publish(
        .configReloadFailed(message: result.errorMessage ?? "unknown")
      )
    }

    easybarLog.info("reloadConfig end")
    isReloadingConfig = false

    if queuedConfigReload {
      queuedConfigReload = false
      await reloadConfig()
    }
  }

  /// Restarts only the Lua runtime without reloading config.
  func restartLuaRuntime() async {
    easybarLog.info("restartLuaRuntime begin")
    await widgetEngine.reload()
    aeroSpaceService.triggerRefresh()
    await eventHub.publish(.luaRuntimeRestarted)
    easybarLog.info("restartLuaRuntime end")
  }

  /// Refreshes the current runtime state without reloading config.
  func refreshRuntime() async {
    easybarLog.info("refreshRuntime begin")
    aeroSpaceService.triggerRefresh()
    EventBus.shared.emit(.manualRefresh)
    await eventHub.publish(.runtimeRefreshed)
    easybarLog.info("refreshRuntime end")
  }

  /// Handles one incoming IPC command.
  func handleSocketCommand(_ command: IPC.Command) async {
    easybarLog.info("handleSocketCommand command=\(command)")
    await eventHub.publish(.ipcCommand(command))

    switch command {
    case .workspaceChanged:
      aeroSpaceService.triggerRefresh()
      EventBus.shared.emit(.workspaceChange)

    case .focusChanged:
      aeroSpaceService.triggerRefresh()
      EventBus.shared.emit(.focusChange)

    case .spaceModeChanged:
      aeroSpaceService.triggerRefresh()
      EventBus.shared.emit(.spaceModeChange)

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

  /// Configures logging from the current config.
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

  /// Starts the actor-based config watcher and subscribes to changes.
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
          await self.eventHub.publish(.configFileChanged)
          await self.reloadConfig()
        }
      }
    }
  }

  /// Restarts the config watcher after config reload.
  private func restartFileWatcher() async {
    await startFileWatcher()
  }

  /// Starts the IPC server and routes commands into the runtime actor.
  private func startSocketServer() async {
    metricsCoordinator.onSnapshot = { [weak self] snapshot in
      self?.socketServer.broadcastMetrics(snapshot)
    }

    socketServer.start { [weak self] command in
      guard let self else { return }

      Task {
        await self.handleSocketCommand(command)
      }
    }
  }
}
