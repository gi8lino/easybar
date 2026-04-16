import Foundation

/// Legacy compatibility façade for config watching.
///
/// The real watcher ownership now lives in the actor-based `FileWatcher`.
final class ConfigFileWatcher {
  static let shared = ConfigFileWatcher()

  var onConfigFileChange: (() -> Void)?

  private var task: Task<Void, Never>?

  private init() {}

  /// Starts watching using the actor-based watcher.
  func start() {
    stop()

    task = Task { [weak self] in
      guard let self else { return }

      let enabled = await ConfigManager.shared.watchConfigFileEnabled()
      let path = await ConfigManager.shared.configPath()
      let stream = await FileWatcher().start(configPath: path, enabled: enabled)

      for await _ in stream {
        await MainActor.run {
          self.onConfigFileChange?()
        }
      }
    }
  }

  /// Restarts watching.
  func restart() {
    stop()
    start()
  }

  /// Stops watching.
  func stop() {
    task?.cancel()
    task = nil
  }
}
