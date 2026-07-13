import Foundation

/// Coordinates config-file watch streams and turns file changes into reload requests.
actor ConfigWatcherCoordinator {
  /// Actor used for runtime config reads.
  private let configManager: ConfigManager
  /// Actor that owns the low-level filesystem watcher.
  private let fileWatcher: FileWatcher
  /// Task consuming config watcher events.
  private var watcherTask: Task<Void, Never>?

  /// Creates one config watcher coordinator.
  init(
    configManager: ConfigManager,
    fileWatcher: FileWatcher
  ) {
    self.configManager = configManager
    self.fileWatcher = fileWatcher
  }

  /// Starts watching the active config file and calls the handler after changes.
  func start(onChange: @escaping @Sendable () async -> Void) async {
    watcherTask?.cancel()
    watcherTask = nil

    let path = await configManager.configPath()
    let enabled = await configManager.watchConfigFileEnabled()
    let stream = await fileWatcher.start(configPath: path, enabled: enabled)

    watcherTask = Task {
      for await event in stream {
        switch event {
        case .changed:
          await onChange()
        }
      }
    }
  }

  /// Restarts the watcher after config reload may have changed path or watch settings.
  func restart(onChange: @escaping @Sendable () async -> Void) async {
    await stop()
    await start(onChange: onChange)
  }

  /// Stops watching config changes.
  func stop() async {
    watcherTask?.cancel()
    watcherTask = nil
    await fileWatcher.stop()
  }
}
