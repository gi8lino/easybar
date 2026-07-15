import Foundation

/// Tracks one Lua runtime generation so queued work cannot cross reload boundaries.
struct WidgetRuntimeSession: Sendable {
  private(set) var id: UInt64 = 0

  /// Starts and returns a fresh runtime session identifier.
  mutating func begin() -> UInt64 {
    id &+= 1
    return id
  }

  /// Invalidates all work captured from the current or earlier session.
  mutating func invalidate() {
    id &+= 1
  }

  /// Returns whether work belongs to the active runtime session.
  func accepts(_ candidate: UInt64, whileRunning: Bool) -> Bool {
    whileRunning && id == candidate
  }
}
