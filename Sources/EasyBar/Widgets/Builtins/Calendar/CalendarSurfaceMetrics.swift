import CoreGraphics

/// Shared geometry helpers for calendar popup and panel surfaces.
enum CalendarSurfaceMetrics {
  /// Returns the visible stroke width for a configured border width.
  static func borderLineWidth(_ configuredWidth: Double) -> CGFloat {
    max(CGFloat(configuredWidth), 0)
  }
}
