import Foundation

/// Actor-based config file watcher.
///
/// It owns the underlying dispatch source and exposes a stream of high-level
/// file-change events to the runtime coordinator.
actor FileWatcher {
  enum Event: Sendable {
    case changed
  }

  private let queue = DispatchQueue(label: "easybar.config-watcher")
  private var fileDescriptor: CInt = -1
  private var source: DispatchSourceFileSystemObject?
  private var debounceWorkItem: DispatchWorkItem?

  private var continuation: AsyncStream<Event>.Continuation?
  private var stream: AsyncStream<Event>?

  /// Starts watching the current config file when enabled.
  func start(configPath: String, enabled: Bool) -> AsyncStream<Event> {
    stop()

    let stream = AsyncStream<Event> { continuation in
      self.continuation = continuation
    }

    self.stream = stream

    guard enabled else {
      easybarLog.debug("config file watcher disabled")
      return stream
    }

    guard let descriptor = openDescriptor(path: configPath) else {
      easybarLog.warn("failed to watch config file at \(configPath)")
      return stream
    }

    fileDescriptor = descriptor

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor,
      eventMask: [.write, .delete, .rename, .attrib, .extend],
      queue: queue
    )

    source.setEventHandler { [weak self] in
      self?.scheduleReloadEvent()
    }

    source.setCancelHandler { [weak self] in
      self?.closeDescriptor()
    }

    self.source = source
    source.resume()

    easybarLog.debug("config file watcher started path=\(configPath)")

    return stream
  }

  /// Restarts the watcher with the latest config.
  func restart(configPath: String, enabled: Bool) -> AsyncStream<Event> {
    start(configPath: configPath, enabled: enabled)
  }

  /// Stops watching and closes the underlying descriptor.
  func stop() {
    debounceWorkItem?.cancel()
    debounceWorkItem = nil

    source?.cancel()
    source = nil

    continuation?.finish()
    continuation = nil
    stream = nil

    closeDescriptor()
  }

  /// Schedules one debounced config-file-changed event.
  private func scheduleReloadEvent() {
    debounceWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.continuation?.yield(.changed)
    }

    debounceWorkItem = workItem
    queue.asyncAfter(deadline: .now() + 0.20, execute: workItem)
  }

  /// Opens the config file descriptor for event watching.
  private func openDescriptor(path: String) -> CInt? {
    let descriptor = open(path, O_EVTONLY)
    guard descriptor >= 0 else { return nil }
    return descriptor
  }

  /// Closes the current file descriptor when present.
  private func closeDescriptor() {
    guard fileDescriptor >= 0 else { return }
    close(fileDescriptor)
    fileDescriptor = -1
  }
}
