import Darwin
import Foundation

/// Actor-owned file watcher that emits debounced config change events.
actor FileWatcher {

  enum Event: Sendable {
    case changed
  }

  private var fileDescriptor: Int32 = -1
  private var source: DispatchSourceFileSystemObject?
  private var debounceWorkItem: DispatchWorkItem?
  private var continuation: AsyncStream<Event>.Continuation?

  /// Starts watching the given config file and returns an event stream.
  func start(configPath: String, enabled: Bool) -> AsyncStream<Event> {
    stop()

    return AsyncStream { continuation in
      Task { [weak self] in
        guard let self else {
          continuation.finish()
          return
        }

        await self.install(
          continuation: continuation,
          configPath: configPath,
          enabled: enabled
        )
      }
    }
  }

  /// Stops the active watcher.
  func stop() {
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
    enabled: Bool
  ) {
    self.continuation = continuation

    continuation.onTermination = { [weak self] _ in
      Task {
        await self?.stop()
      }
    }

    guard enabled else { return }

    let fd = open(configPath, O_EVTONLY)
    guard fd >= 0 else {
      easybarLog.warn("file watcher failed to open path=\(configPath)")
      return
    }

    fileDescriptor = fd

    let queue = DispatchQueue(label: "easybar.file-watcher", qos: .utility)
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
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

  /// Schedules one debounced change event.
  private func scheduleReloadEvent() {
    debounceWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      Task {
        await self?.emitChanged()
      }
    }

    debounceWorkItem = workItem

    DispatchQueue.main.asyncAfter(
      deadline: .now() + 0.25,
      execute: workItem
    )
  }

  /// Emits one debounced changed event.
  private func emitChanged() {
    continuation?.yield(.changed)
  }

  /// Closes the watched file descriptor when present.
  private func closeDescriptor() {
    guard fileDescriptor >= 0 else { return }
    close(fileDescriptor)
    fileDescriptor = -1
  }
}
