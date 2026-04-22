import Foundation

/// Native calendar anchor widget.
///
/// Responsible only for:
/// - event handling
/// - agent lifecycle
/// - snapshot creation
/// - delegating rendering
@MainActor
final class CalendarNativeWidget: NativeWidget {

  let rootID = "builtin_calendar"

  var appEventSubscriptions: Set<String> {
    let refreshEvent = Self.refreshEvent(for: Config.shared.builtinCalendar)
    return [
      refreshEvent.rawValue,
      AppEvent.systemWoke.rawValue,
      AppEvent.calendarChange.rawValue,
    ]
  }

  private let eventObserver = EasyBarEventObserver()
  private lazy var renderer = CalendarRenderer(rootID: rootID)

  private var started = false
  private var startedCalendarAgent = false
  private var startedPopupMode: Config.CalendarPopupMode = .none

  struct Snapshot {
    let config: Config.CalendarBuiltinConfig
    let now: Date
  }

  // MARK: - Lifecycle

  /// Starts the calendar widget.
  func start() {
    guard !started else { return }
    started = true

    let snapshot = currentSnapshot()

    NativeWidgetEventDriver.start(
      observer: eventObserver,
      eventNames: appEventSubscriptions
    ) { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }

      switch event {
      case Self.refreshEvent(for: Config.shared.builtinCalendar), .systemWoke, .calendarChange:
        self.publish()
      default:
        break
      }
    }

    startedCalendarAgent = snapshot.config.enabled && Config.shared.calendarAgentEnabled
    startedPopupMode = snapshot.config.popupMode

    if startedCalendarAgent {
      startCalendarAgent(for: snapshot)
    }

    publish()
  }

  /// Stops the calendar widget.
  func stop() {
    guard started else { return }
    started = false

    eventObserver.stop()

    if startedCalendarAgent {
      stopCalendarAgent()
      NativeUpcomingCalendarStore.shared.clear()
      NativeMonthCalendarStore.shared.clear()
    }

    startedCalendarAgent = false
    startedPopupMode = .none

    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  // MARK: - Publish

  /// Publishes the current calendar anchor nodes.
  private func publish() {
    let snapshot = currentSnapshot()
    WidgetStore.shared.apply(
      root: rootID,
      nodes: renderer.makeNodes(snapshot: snapshot)
    )
  }

  // MARK: - Snapshot

  /// Returns the current calendar render snapshot.
  private func currentSnapshot() -> Snapshot {
    Snapshot(
      config: Config.shared.builtinCalendar,
      now: Date()
    )
  }

  /// Returns the fetch range required by the upcoming popup.
  static func requestedDateRange(
    config: Config.CalendarBuiltinConfig,
    now: Date
  ) -> DateInterval {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: now)
    let dayCount = max(1, config.upcoming.events.days)

    let end =
      calendar.date(byAdding: .day, value: dayCount, to: start)
      ?? now.addingTimeInterval(TimeInterval(dayCount * 86_400))

    return DateInterval(start: start, end: end)
  }

  /// Returns the cheapest tick cadence that keeps the active anchor layout current.
  private static func refreshEvent(for config: Config.CalendarBuiltinConfig) -> AppEvent {
    let needsSecondPrecision = activeFormats(for: config).contains { format in
      FormattedClockRefreshPolicy.event(for: format) == .secondTick
    }
    return needsSecondPrecision ? .secondTick : .minuteTick
  }

  /// Returns only the format strings used by the current anchor layout.
  private static func activeFormats(for config: Config.CalendarBuiltinConfig) -> [String] {
    switch config.anchor.layout {
    case .stack, .inline:
      return [config.anchor.topFormat, config.anchor.bottomFormat]
    case .item:
      return [config.anchor.itemFormat]
    }
  }
}

// MARK: - Agent Lifecycle

extension CalendarNativeWidget {

  /// Starts the calendar agent required by the active popup mode.
  private func startCalendarAgent(for snapshot: Snapshot) {
    switch snapshot.config.popupMode {
    case .none:
      break
    case .upcoming:
      UpcomingCalendarAgentClient.shared.start()
    case .month:
      MonthCalendarAgentClient.shared.start()
      MonthCalendarAgentClient.shared.focusVisibleMonth(snapshot.now)
    }
  }

  /// Stops the calendar agent required by the started popup mode.
  private func stopCalendarAgent() {
    switch startedPopupMode {
    case .none:
      break
    case .upcoming:
      UpcomingCalendarAgentClient.shared.stop()
    case .month:
      MonthCalendarAgentClient.shared.stop()
    }
  }
}
