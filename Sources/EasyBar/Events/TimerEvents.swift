import EasyBarShared
import Foundation

final class TimerEvents {
  private static var sharedInstance: TimerEvents?

  /// Returns the configured shared timer event source.
  static var shared: TimerEvents {
    guard let sharedInstance else {
      fatalError("TimerEvents.bootstrap(logger:) must be called before TimerEvents.shared")
    }

    return sharedInstance
  }

  /// Configures the shared timer event source.
  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = TimerEvents(logger: logger)
  }

  private let logger: ProcessLogger

  private var minuteTimer: Timer?
  private var secondTimer: Timer?
  private var intervalTimer: Timer?

  /// Creates one timer event source.
  private init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Starts the minute timer used by Lua `minute_tick` subscriptions.
  func startMinuteTimer() {
    minuteTimer?.invalidate()
    minuteTimer = makeAlignedTimer(
      interval: 60,
      tolerance: 1,
      event: .minuteTick
    )

    logger.debug("minute timer started")
  }

  /// Stops the minute timer.
  func stopMinuteTimer() {
    minuteTimer?.invalidate()
    minuteTimer = nil
  }

  /// Starts the second timer used by explicit `second_tick` subscriptions.
  func startSecondTimer() {
    secondTimer?.invalidate()
    secondTimer = makeAlignedTimer(
      interval: 1,
      tolerance: 0.05,
      event: .secondTick
    )

    logger.debug("second timer started")
  }

  /// Stops the second timer.
  func stopSecondTimer() {
    secondTimer?.invalidate()
    secondTimer = nil
  }

  /// Starts the interval timer used by Lua `interval` callbacks.
  func startIntervalTimer(interval: TimeInterval) {
    intervalTimer?.invalidate()
    intervalTimer = makeAlignedTimer(
      interval: interval,
      tolerance: min(1, max(0.05, interval * 0.05)),
      event: .intervalTick
    )

    logger.debug("interval timer started", .field("interval", interval))
  }

  /// Stops the interval timer.
  func stopIntervalTimer() {
    intervalTimer?.invalidate()
    intervalTimer = nil
  }

  /// Stops and clears all active timers.
  func stopAll() {
    stopMinuteTimer()
    stopSecondTimer()
    stopIntervalTimer()
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
