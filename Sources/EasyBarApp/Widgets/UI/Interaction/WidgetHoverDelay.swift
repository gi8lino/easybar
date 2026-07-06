/// Shared hover delay used to avoid flicker between adjacent widget hover surfaces.
enum WidgetHoverDelay {
  /// Delay in nanoseconds before a hover exit or popup close is committed.
  static let nanoseconds: UInt64 = 80_000_000

  /// Suspends for the shared hover delay.
  static func sleep() async throws {
    try await Task.sleep(nanoseconds: nanoseconds)
  }
}
