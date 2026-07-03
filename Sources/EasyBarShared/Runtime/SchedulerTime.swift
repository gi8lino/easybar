import Foundation

/// Converts a scheduler delay into safe `Task.sleep` nanoseconds.
///
/// The scheduler inputs are runtime configuration values or backoff values. They
/// should never be allowed to trap during `Double` to `UInt64` conversion. Invalid
/// or negative delays run immediately, while positive overflow is capped at the
/// largest representable sleep duration.
func clampedSleepNanoseconds(from delay: TimeInterval) -> UInt64 {
  guard !delay.isNaN else {
    return 0
  }

  guard delay.isFinite else {
    return delay > 0 ? UInt64.max : 0
  }

  guard delay > 0 else {
    return 0
  }

  let nanoseconds = delay * 1_000_000_000
  guard nanoseconds.isFinite else {
    return UInt64.max
  }

  guard nanoseconds < Double(UInt64.max) else {
    return UInt64.max
  }

  return UInt64(nanoseconds)
}
