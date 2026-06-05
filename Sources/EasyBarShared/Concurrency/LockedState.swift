import Foundation

/// Small shared wrapper around `NSLock` for synchronous state
/// that still has to be queried from non-async APIs.
///
/// Sendability is provided by the internal `NSLock`; callers can only read or
/// mutate the wrapped state inside `withLock`.
public final class LockedState<State>: @unchecked Sendable {
  private let lock = NSLock()
  private var state: State

  /// Creates a locked state container.
  public init(_ state: State) {
    self.state = state
  }

  /// Runs one closure while holding the lock.
  public func withLock<T>(_ body: (inout State) throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }

    return try body(&state)
  }
}
