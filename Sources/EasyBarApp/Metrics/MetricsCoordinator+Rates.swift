import Foundation

extension MetricsCoordinator {
  /// Computes a per-second rate from cumulative counters.
  func rate(
    current: Int,
    previous: Int?,
    context: RateContext
  ) -> Double {
    guard context.collectionEnabled, let previous else { return 0 }
    guard context.interval > 0 else { return 0 }

    let delta = max(0, current - previous)
    return Double(delta) / context.interval
  }
}
