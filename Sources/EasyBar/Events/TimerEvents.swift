import Foundation

final class TimerEvents {

  static let shared = TimerEvents()

  private var timers: [Timer] = []

  private init() {}

  func startMinuteTimer() {

    let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
      EventBus.shared.emit(.minuteTick)
    }

    timers.append(timer)

    Logger.debug("minute timer started")
  }

  func startSecondTimer() {

    let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      EventBus.shared.emit(.secondTick)
    }

    timers.append(timer)

    Logger.debug("second timer started")
  }

  func stopAll() {
    for timer in timers {
      timer.invalidate()
    }

    timers.removeAll()
  }
}
