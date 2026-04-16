import Foundation

final class TimerEvents {
  static let shared = TimerEvents()

  private var minuteTimer: Timer?
  private var secondTimer: Timer?

  private init() {}

  /// Starts the minute timer used by Lua `minute_tick` subscriptions.
  func startMinuteTimer() {
    minuteTimer?.invalidate()
    minuteTimer = makeAlignedTimer(
      interval: 60,
      tolerance: 1,
      event: .minuteTick
    )

    easybarLog.debug("minute timer started")
  }

  /// Starts the second timer used by Lua `second_tick` and `routine` subscriptions.
  func startSecondTimer() {
    secondTimer?.invalidate()
    secondTimer = makeAlignedTimer(
      interval: 1,
      tolerance: 0.05,
      event: .secondTick
    )

    easybarLog.debug("second timer started")
  }

  /// Stops and clears all active timers.
  func stopAll() {
    minuteTimer?.invalidate()
    secondTimer?.invalidate()
    minuteTimer = nil
    secondTimer = nil
  }

  /// Starts one repeating timer aligned to the next real wall-clock boundary.
  private func makeAlignedTimer(
    interval: TimeInterval,
    tolerance: TimeInterval,
    event: AppEvent
  ) -> Timer {
    let timer = Timer(
      fire: nextBoundary(after: Date(), interval: interval),
      interval: interval,
      repeats: true
    ) { _ in
      Task {
        await EventHub.shared.emit(event)
      }
    }

    timer.tolerance = tolerance
    RunLoop.main.add(timer, forMode: .common)
    return timer
  }

  /// Returns the next whole second or minute boundary after the given time.
  private func nextBoundary(after date: Date, interval: TimeInterval) -> Date {
    let current = date.timeIntervalSinceReferenceDate
    let nextStep = floor(current / interval) + 1
    return Date(timeIntervalSinceReferenceDate: nextStep * interval)
  }
}
