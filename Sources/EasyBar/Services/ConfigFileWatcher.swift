import Foundation

/// Watches config.toml for changes and reloads EasyBar automatically.
final class ConfigFileWatcher {

  static let shared = ConfigFileWatcher()

  private let queue = DispatchQueue(label: "easybar.config-watcher")
  private var fileDescriptor: CInt = -1
  private var source: DispatchSourceFileSystemObject?
  private var debounceWorkItem: DispatchWorkItem?

  private init() {}

  /// Starts watching the config file if enabled.
  func start() {
    stop()

    guard Config.shared.watchConfigFile else {
      Logger.debug("config file watcher disabled")
      return
    }

    let path = Config.shared.configPath
    guard let descriptor = openDescriptor(path: path) else {
      Logger.warn("failed to watch config file at \(path)")
      return
    }

    fileDescriptor = descriptor

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor,
      eventMask: [.write, .delete, .rename, .attrib, .extend],
      queue: queue
    )

    // Reload after a short debounce so editors can finish writing.
    source.setEventHandler { [weak self] in
      self?.scheduleReload()
    }

    source.setCancelHandler { [weak self] in
      self?.closeDescriptor()
    }

    self.source = source
    source.resume()

    Logger.debug("config file watcher started path=\(path)")
  }

  /// Restarts the watcher after config reload or file replacement.
  func restart() {
    stop()
    start()
  }

  /// Stops watching the config file.
  func stop() {
    debounceWorkItem?.cancel()
    debounceWorkItem = nil

    source?.cancel()
    source = nil
    closeDescriptor()
  }

  /// Schedules one debounced reload.
  private func scheduleReload() {
    debounceWorkItem?.cancel()

    let work = DispatchWorkItem { [weak self] in self?.performReload() }
    debounceWorkItem = work
    queue.asyncAfter(deadline: .now() + 0.20, execute: work)
  }

  /// Reloads config and refreshes all dependent systems.
  private func performReload() {
    DispatchQueue.main.async {
      Logger.info("config file changed, reloading")

      Config.shared.reload()
      WidgetRunner.shared.reload()
      NativeWidgetRegistry.shared.reload()
      AeroSpaceService.shared.triggerRefresh()

      // Some editors replace the file atomically, so re-open the watcher.
      self.restart()
    }
  }

  /// Opens the config file for filesystem event watching.
  private func openDescriptor(path: String) -> CInt? {
    let descriptor = open(path, O_EVTONLY)
    guard descriptor >= 0 else { return nil }
    return descriptor
  }

  /// Closes the watched file descriptor when present.
  private func closeDescriptor() {
    guard fileDescriptor >= 0 else { return }
    close(fileDescriptor)
    fileDescriptor = -1
  }
}
