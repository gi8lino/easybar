import EasyBarShared
import Foundation

/// Widget-scoped interval schedule requested by the Lua runtime.
struct WidgetIntervalSchedule: Hashable, Sendable {
  let widgetID: String
  let interval: TimeInterval
}

/// Owns app event timers.
final class TimerEvents {
  /// Shared timer event source.
  /// Logger used for timer diagnostics.
  private let logger: ProcessLogger

  /// Timer for minute ticks.
  private var minuteTimer: Timer?
  /// Timer for second ticks.
  private var secondTimer: Timer?
  /// Timers for widget-scoped Lua interval callbacks.
  private var intervalTimers: [String: Timer] = [:]

  /// Creates one timer event source.
  init(logger: ProcessLogger) {
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

  /// Replaces every widget-scoped interval timer used by Lua `interval` callbacks.
  func replaceIntervalTimers(schedules: Set<WidgetIntervalSchedule>) {
    stopIntervalTimers()

    for schedule in schedules {
      let timer = makeRepeatingTimer(
        interval: schedule.interval,
        tolerance: min(1, max(0.05, schedule.interval * 0.05))
      ) { [widgetID = schedule.widgetID] in
        Task {
          await EventHub.shared.emit(.app(.intervalTick, widgetID: widgetID))
        }
      }

      intervalTimers[schedule.widgetID] = timer

      logger.debug(
        "interval timer started",
        .field("widget_id", schedule.widgetID),
        .field("interval", schedule.interval),
      )
    }
  }

  /// Stops every widget-scoped interval timer.
  func stopIntervalTimers() {
    for timer in intervalTimers.values {
      timer.invalidate()
    }

    intervalTimers.removeAll()
  }

  /// Stops and clears all active timers.
  func stopAll() {
    stopMinuteTimer()
    stopSecondTimer()
    stopIntervalTimers()
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

  /// Starts one repeating timer relative to its creation time.
  private func makeRepeatingTimer(
    interval: TimeInterval,
    tolerance: TimeInterval,
    onFire: @escaping @Sendable () -> Void
  ) -> Timer {
    let timer = Timer(
      fire: Date().addingTimeInterval(interval),
      interval: interval,
      repeats: true
    ) { _ in
      onFire()
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
