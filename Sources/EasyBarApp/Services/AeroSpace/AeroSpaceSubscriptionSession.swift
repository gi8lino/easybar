import EasyBarShared
import Foundation

/// Schedules AeroSpace subscription reconnect attempts.
protocol AeroSpaceReconnectScheduling: Sendable {
  /// Schedules one reconnect action.
  func schedule(_ action: @escaping @Sendable () -> Void)
  /// Cancels any pending reconnect action.
  func cancel()
  /// Resets the reconnect delay sequence.
  func resetDelay()
}

extension BackoffScheduler: AeroSpaceReconnectScheduling {}

/// Creates AeroSpace subscription sessions.
protocol AeroSpaceSubscriptionLaunching: Sendable {
  /// Returns whether a subscription can currently be launched.
  func canLaunchSubscription(arguments: [String]) -> Bool
  /// Creates one subscription session.
  func makeSubscription(arguments: [String]) -> AeroSpaceSubscriptionSession?
}

/// One launchable AeroSpace subscription session.
protocol AeroSpaceSubscriptionSession: AnyObject, Sendable {
  /// Process-style termination status from the finished subscription.
  var terminationStatus: Int32 { get }

  /// Starts the subscription and installs stream/termination callbacks.
  func start(
    onOutputData: @escaping @Sendable (Data) -> Void,
    onErrorData: @escaping @Sendable (Data) -> Void,
    onTermination: @escaping @Sendable (AeroSpaceSubscriptionSession) -> Void
  ) throws

  /// Stops the subscription and releases its resources.
  func stop()

  /// Releases callbacks and file descriptors without changing controller lifecycle state.
  func invalidate()
}
