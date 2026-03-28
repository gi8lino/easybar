import Foundation

final class TimerEvents {

  static let shared = TimerEvents()

  private var timers: [Timer] = []

  private init() {}

  /// Starts the minute timer used by Lua `minute_tick` subscriptions.
  func startMinuteTimer() {
    let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
      EventBus.shared.emit(.minuteTick)
    }

    timers.append(timer)

    Logger.debug("minute timer started")
  }

  /// Starts the second timer used by Lua `second_tick` and `routine` subscriptions.
  func startSecondTimer() {
    let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      EventBus.shared.emit(.secondTick)
    }

    timers.append(timer)

    Logger.debug("second timer started")
  }

  /// Stops and clears all active timers.
  func stopAll() {
    for timer in timers {
      timer.invalidate()
    }

    timers.removeAll()
  }
}
