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
  let widgetStore: WidgetStore

  var appEventSubscriptions: Set<String> {
    let refreshEvent = Self.refreshEvent(for: config)
    return [
      refreshEvent.rawValue,
      AppEvent.systemWoke.rawValue,
      AppEvent.calendarChange.rawValue,
    ]
  }

  private let config: Config.CalendarBuiltinConfig
  private let calendarAgentConfig: ConfigSnapshot.CalendarAgent
  private let nativeUpcomingCalendarStore: NativeUpcomingCalendarStore
  private let nativeMonthCalendarStore: NativeMonthCalendarStore
  private let nativeComposerCalendarStore: NativeComposerCalendarStore
  private let upcomingCalendarAgentClient: UpcomingCalendarAgentClient
  private let monthCalendarAgentClient: MonthCalendarAgentClient
  private let eventObserver: EasyBarEventObserver
  private lazy var renderer = CalendarRenderer(rootID: rootID)

  private var started = false
  private var startedCalendarAgent = false
  private var startedPopupMode: Config.CalendarPopupMode = .none

  struct Snapshot {
    let config: Config.CalendarBuiltinConfig
    let now: Date
  }

  /// Creates the native calendar widget from immutable config sections.
  init(
    config: Config.CalendarBuiltinConfig,
    calendarAgentConfig: ConfigSnapshot.CalendarAgent,
    widgetStore: WidgetStore,
    nativeUpcomingCalendarStore: NativeUpcomingCalendarStore,
    nativeMonthCalendarStore: NativeMonthCalendarStore,
    nativeComposerCalendarStore: NativeComposerCalendarStore,
    upcomingCalendarAgentClient: UpcomingCalendarAgentClient,
    monthCalendarAgentClient: MonthCalendarAgentClient,
    eventHub: EventHub
  ) {
    self.config = config
    self.calendarAgentConfig = calendarAgentConfig
    self.widgetStore = widgetStore
    self.nativeUpcomingCalendarStore = nativeUpcomingCalendarStore
    self.nativeMonthCalendarStore = nativeMonthCalendarStore
    self.nativeComposerCalendarStore = nativeComposerCalendarStore
    self.upcomingCalendarAgentClient = upcomingCalendarAgentClient
    self.monthCalendarAgentClient = monthCalendarAgentClient
    self.eventObserver = EasyBarEventObserver(eventHub: eventHub)
  }

  // MARK: - Lifecycle

  /// Starts the calendar widget.
  func start() {
    guard !started else { return }
    started = true

    let snapshot = currentSnapshot()

    eventObserver.start(eventNames: appEventSubscriptions) { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }

      switch event {
      case Self.refreshEvent(for: self.config), .systemWoke, .calendarChange:
        self.publish()
      default:
        break
      }
    }

    startedCalendarAgent = snapshot.config.enabled && calendarAgentConfig.enabled
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
      nativeUpcomingCalendarStore.clear()
      nativeMonthCalendarStore.clear()
      nativeComposerCalendarStore.clear()
    }

    startedCalendarAgent = false
    startedPopupMode = .none

    clearNodes()
  }

  // MARK: - Publish

  /// Publishes the current calendar anchor nodes.
  private func publish() {
    let snapshot = currentSnapshot()
    applyNodes(renderer.makeNodes(snapshot: snapshot))
  }

  // MARK: - Snapshot

  /// Returns the current calendar render snapshot.
  private func currentSnapshot() -> Snapshot {
    Snapshot(
      config: config,
      now: Date()
    )
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
      upcomingCalendarAgentClient.start()
    case .month:
      monthCalendarAgentClient.start()
      monthCalendarAgentClient.focusVisibleMonth(snapshot.now)
    }
  }

  /// Stops the calendar agent required by the started popup mode.
  private func stopCalendarAgent() {
    switch startedPopupMode {
    case .none:
      break
    case .upcoming:
      upcomingCalendarAgentClient.stop()
    case .month:
      monthCalendarAgentClient.stop()
    }
  }
}
