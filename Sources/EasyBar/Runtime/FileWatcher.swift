import Darwin
import EasyBarShared
import Foundation

/// Actor-owned file watcher that emits debounced config change events.
actor FileWatcher {

  /// File watcher events emitted to the runtime coordinator.
  enum Event: Sendable {
    /// The watched config file or nearest ancestor changed.
    case changed
  }

  /// File descriptor currently watched by the dispatch source.
  private var fileDescriptor: Int32 = -1
  /// Dispatch source observing filesystem changes.
  private var source: DispatchSourceFileSystemObject?
  /// Pending debounced change emission.
  private var debounceWorkItem: DispatchWorkItem?
  /// Active stream continuation.
  private var continuation: AsyncStream<Event>.Continuation?
  /// Generation used to ignore stale watcher callbacks.
  private var watcherGeneration: UInt64 = 0
  /// Queue used to debounce filesystem events.
  private let debounceQueue = DispatchQueue(label: "easybar.file-watcher.debounce", qos: .utility)
  /// Logger used for file watcher diagnostics.
  private let logger: ProcessLogger

  /// Creates one config file watcher.
  init(
    logger: ProcessLogger
  ) {
    self.logger = logger
  }

  /// Starts watching the given config file and returns an event stream.
  func start(configPath: String, enabled: Bool) -> AsyncStream<Event> {
    stop()
    let generation = watcherGeneration

    return AsyncStream { continuation in
      Task { [weak self] in
        guard let self else {
          continuation.finish()
          return
        }

        await self.install(
          continuation: continuation,
          configPath: configPath,
          enabled: enabled,
          generation: generation
        )
      }
    }
  }

  /// Stops the active watcher.
  func stop() {
    watcherGeneration &+= 1
    debounceWorkItem?.cancel()
    debounceWorkItem = nil

    continuation?.finish()
    continuation = nil

    source?.setEventHandler {}
    source?.setCancelHandler {}
    source?.cancel()
    source = nil

    closeDescriptor()
  }

  /// Installs one watcher when enabled and the file can be opened.
  private func install(
    continuation: AsyncStream<Event>.Continuation,
    configPath: String,
    enabled: Bool,
    generation: UInt64
  ) {
    guard generation == watcherGeneration else {
      continuation.finish()
      return
    }

    self.continuation = continuation

    continuation.onTermination = { [weak self] _ in
      Task {
        await self?.handleTermination(generation: generation)
      }
    }

    guard enabled else { return }

    guard let watchTarget = openWatchTarget(for: configPath) else {
      logger.warn(
        "file watcher failed to open watch target",
        .field("path", configPath))
      return
    }

    fileDescriptor = watchTarget.fd
    logger.debug(
      "file watcher watching",
      .field("path", "\(watchTarget.path)"),
      .field("target", "\(configPath)"),
    )

    let queue = DispatchQueue(label: "easybar.file-watcher", qos: .utility)
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: watchTarget.fd,
      eventMask: [.write, .delete, .rename, .attrib, .extend, .link, .revoke],
      queue: queue
    )

    source.setEventHandler { [weak self] in
      Task {
        await self?.scheduleReloadEvent()
      }
    }

    source.setCancelHandler { [weak self] in
      Task {
        await self?.closeDescriptor()
      }
    }

    self.source = source
    source.resume()
  }

  /// Stops the watcher only when the terminating stream still owns the active installation.
  private func handleTermination(generation: UInt64) {
    guard generation == watcherGeneration else { return }
    stop()
  }

  /// Schedules one debounced change event.
  private func scheduleReloadEvent() {
    debounceWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      Task {
        await self?.emitChanged()
      }
    }

    debounceWorkItem = workItem

    debounceQueue.asyncAfter(
      deadline: .now() + 0.25,
      execute: workItem
    )
  }

  /// Emits one debounced changed event.
  private func emitChanged() {
    continuation?.yield(.changed)
  }

  /// Opens the config file when present, otherwise the nearest existing ancestor.
  private func openWatchTarget(for configPath: String) -> (fd: Int32, path: String)? {
    var candidateURL = URL(fileURLWithPath: configPath)

    while true {
      let candidatePath = candidateURL.path
      let fd = open(candidatePath, O_EVTONLY)

      if fd >= 0 {
        return (fd, candidatePath)
      }

      let parentURL = candidateURL.deletingLastPathComponent()
      guard parentURL.path != candidatePath else {
        return nil
      }

      candidateURL = parentURL
    }
  }

  /// Closes the watched file descriptor when present.
  private func closeDescriptor() {
    guard fileDescriptor >= 0 else { return }
    close(fileDescriptor)
    fileDescriptor = -1
  }
}
