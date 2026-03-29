import EasyBarShared
import Foundation

final class CalendarAgentClient {
  static let shared = CalendarAgentClient()

  private lazy var client = AgentSocketClient<CalendarAgentRequest, CalendarAgentMessage>(
    label: "calendar agent client",
    socketPath: { Config.shared.calendarAgentSocketPath },
    subscribeRequest: { [weak self] in
      CalendarAgentRequest(command: .subscribe, query: self?.currentQuery())
    },
    handleMessage: { [weak self] message in
      self?.handle(message)
    },
    clearState: {
      DispatchQueue.main.async {
        NativeCalendarStore.shared.clear()
      }
    }
  )

  private init() {}

  /// Returns whether the client currently has an open socket.
  var isConnected: Bool {
    client.isConnected
  }

  func start() {
    client.start()
  }

  func stop() {
    client.stop()
  }

  private func handle(_ message: CalendarAgentMessage) {
    switch message.kind {
    case .subscribed:
      Logger.info("calendar agent client subscribed")

    case .snapshot:
      guard let snapshot = message.snapshot else { return }
      publish(snapshot: snapshot)

    case .pong:
      break

    case .error:
      Logger.warn("calendar agent error=\(message.message ?? "unknown")")
    }
  }

  private func currentQuery() -> CalendarAgentQuery {
    let config = Config.shared.builtinCalendar

    return CalendarAgentQuery(
      days: config.days,
      showBirthdays: config.showBirthdays,
      emptyText: config.emptyText,
      birthdaysTitle: config.birthdaysTitle,
      birthdaysDateFormat: config.birthdaysDateFormat,
      birthdaysShowAge: config.birthdaysShowAge
    )
  }

  /// Publishes one snapshot to the shared store on the main queue.
  private func publish(snapshot: CalendarAgentSnapshot) {
    DispatchQueue.main.async {
      NativeCalendarStore.shared.apply(snapshot: snapshot)
      EventBus.shared.emit(.calendarChange)
    }
  }
}
