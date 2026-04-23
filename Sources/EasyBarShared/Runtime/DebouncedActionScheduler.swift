import Foundation

/// Schedules one replaceable delayed action on a dispatch queue.
public final class DebouncedActionScheduler {
  private let label: String?
  private let delay: TimeInterval
  private let queue: DispatchQueue
  private let debugLog: (String) -> Void

  private var pendingWorkItem: DispatchWorkItem?

  /// Creates one debounced scheduler.
  public init(
    label: String? = nil,
    delay: TimeInterval,
    queue: DispatchQueue = .main,
    debugLog: @escaping (String) -> Void = { _ in }
  ) {
    self.label = label
    self.delay = delay
    self.queue = queue
    self.debugLog = debugLog
  }

  /// Replaces any pending action with a new delayed action.
  public func schedule(_ action: @escaping () -> Void) {
    pendingWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      self?.pendingWorkItem = nil
      action()
    }

    pendingWorkItem = workItem

    if let label {
      debugLog("\(label) scheduled delay=\(delay)")
    }

    queue.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  /// Cancels any pending action.
  public func cancel() {
    pendingWorkItem?.cancel()
    pendingWorkItem = nil
  }
}
