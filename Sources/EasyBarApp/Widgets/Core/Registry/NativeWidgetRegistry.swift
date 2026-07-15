import EasyBarShared
import Foundation

@MainActor
final class NativeWidgetRegistry {
  private struct Registration {
    let id: String
    let enabled: Bool
    let makeWidget: () -> NativeWidget
  }

  private let logger: ProcessLogger
  private let widgetStore: WidgetStore
  private let eventManager: EventManager
  private let eventHub: EventHub
  private let aeroSpaceService: AeroSpaceService
  private let networkAgentClient: NetworkAgentClient
  private let nativeWiFiStore: NativeWiFiStore
  private let nativeUpcomingCalendarStore: NativeUpcomingCalendarStore
  private let nativeMonthCalendarStore: NativeMonthCalendarStore
  private let nativeComposerCalendarStore: NativeComposerCalendarStore
  private let upcomingCalendarAgentClient: UpcomingCalendarAgentClient
  private let monthCalendarAgentClient: MonthCalendarAgentClient
  private let nativeGroupRegistry: NativeGroupRegistry
  private var snapshot: ConfigSnapshot
  private var widgets: [NativeWidget] = []

  init(
    logger: ProcessLogger,
    snapshot: ConfigSnapshot,
    widgetStore: WidgetStore,
    eventManager: EventManager,
    eventHub: EventHub,
    aeroSpaceService: AeroSpaceService,
    networkAgentClient: NetworkAgentClient,
    nativeWiFiStore: NativeWiFiStore,
    nativeUpcomingCalendarStore: NativeUpcomingCalendarStore,
    nativeMonthCalendarStore: NativeMonthCalendarStore,
    nativeComposerCalendarStore: NativeComposerCalendarStore,
    upcomingCalendarAgentClient: UpcomingCalendarAgentClient,
    monthCalendarAgentClient: MonthCalendarAgentClient
  ) {
    self.logger = logger
    self.snapshot = snapshot
    self.widgetStore = widgetStore
    self.eventManager = eventManager
    self.eventHub = eventHub
    self.aeroSpaceService = aeroSpaceService
    self.networkAgentClient = networkAgentClient
    self.nativeWiFiStore = nativeWiFiStore
    self.nativeUpcomingCalendarStore = nativeUpcomingCalendarStore
    self.nativeMonthCalendarStore = nativeMonthCalendarStore
    self.nativeComposerCalendarStore = nativeComposerCalendarStore
    self.upcomingCalendarAgentClient = upcomingCalendarAgentClient
    self.monthCalendarAgentClient = monthCalendarAgentClient
    self.nativeGroupRegistry = NativeGroupRegistry(widgetStore: widgetStore)
  }

  /// Starts all enabled native widgets using the current immutable config snapshot.
  func start(snapshot: ConfigSnapshot? = nil) {
    if let snapshot {
      self.snapshot = snapshot
    }

    registerAll()
  }

  /// Rebuilds the native widget list from an immutable config snapshot.
  func reload(snapshot: ConfigSnapshot) {
    self.snapshot = snapshot
    registerAll()
  }

  /// Stops all native widgets.
  func stop() {
    stopAll()
  }

  /// Registers all enabled native widgets.
  private func registerAll() {
    logger.debug("native widget registry registerAll begin")

    stopAll()

    let registrations = registrations()

    logger.debug("registering native widgets")
    logConfig(registrations)

    nativeGroupRegistry.reload(groups: snapshot.builtins.groups)
    widgets = makeEnabledWidgets(from: registrations)

    logRegisteredWidgets()

    applyNativeEventSubscriptions()
    startWidgets()

    logger.debug("native widget registry registerAll end")
  }

  /// Stops and clears all widgets.
  private func stopAll() {
    if !widgets.isEmpty {
      logger.debug(
        "native widget registry stopping",
        .field("count", widgets.count),
      )
    }

    for widget in widgets {
      logger.debug(
        "stopping native widget",
        .field("id", widget.rootID),
      )
      widget.stop()
    }

    widgets.removeAll()
    eventManager.setNativeSubscriptions([])
    nativeGroupRegistry.clear()
  }

  /// Builds the enabled native widget list from the current config snapshot.
  private func makeEnabledWidgets(from registrations: [Registration]) -> [NativeWidget] {
    return registrations.compactMap(makeWidgetIfEnabled)
  }

  /// Returns the native widget registration list for the current config snapshot.
  private func registrations() -> [Registration] {
    let snapshot = self.snapshot
    let builtins = snapshot.builtins
    let networkAgent = snapshot.networkAgent
    let calendarAgent = snapshot.calendarAgent

    return [
      Registration(id: "spaces", enabled: builtins.spaces.enabled) {
        SpacesNativeWidget(
          config: builtins.spaces,
          widgetStore: self.widgetStore,
          aeroSpaceService: self.aeroSpaceService
        )
      },
      Registration(id: "battery", enabled: builtins.battery.enabled) {
        BatteryNativeWidget(
          config: builtins.battery,
          widgetStore: self.widgetStore,
          eventHub: self.eventHub
        )
      },
      Registration(id: "front_app", enabled: builtins.frontApp.enabled) {
        FrontAppNativeWidget(
          config: builtins.frontApp,
          widgetStore: self.widgetStore,
          aeroSpaceService: self.aeroSpaceService
        )
      },
      Registration(id: "aerospace_mode", enabled: builtins.aerospaceMode.enabled) {
        AeroSpaceModeNativeWidget(
          config: builtins.aerospaceMode,
          widgetStore: self.widgetStore,
          aeroSpaceService: self.aeroSpaceService
        )
      },
      Registration(id: "volume", enabled: builtins.volume.enabled) {
        VolumeSliderNativeWidget(
          config: builtins.volume,
          widgetStore: self.widgetStore,
          eventHub: self.eventHub
        )
      },
      Registration(id: "wifi", enabled: builtins.wifi.enabled) {
        WiFiNativeWidget(
          config: builtins.wifi,
          networkAgentConfig: networkAgent,
          widgetStore: self.widgetStore,
          networkAgentClient: self.networkAgentClient,
          nativeWiFiStore: self.nativeWiFiStore,
          eventHub: self.eventHub
        )
      },
      Registration(id: "date", enabled: builtins.date.enabled) {
        FormattedClockNativeWidget(
          rootID: "builtin_date",
          widgetStore: self.widgetStore,
          eventHub: self.eventHub,
          snapshot: .init(
            placement: builtins.date.placement,
            style: builtins.date.style,
            format: builtins.date.format
          )
        )
      },
      Registration(id: "time", enabled: builtins.time.enabled) {
        FormattedClockNativeWidget(
          rootID: "builtin_time",
          widgetStore: self.widgetStore,
          eventHub: self.eventHub,
          snapshot: .init(
            placement: builtins.time.placement,
            style: builtins.time.style,
            format: builtins.time.format
          )
        )
      },
      Registration(id: "calendar", enabled: builtins.calendar.enabled) {
        CalendarNativeWidget(
          config: builtins.calendar,
          calendarAgentConfig: calendarAgent,
          widgetStore: self.widgetStore,
          nativeUpcomingCalendarStore: self.nativeUpcomingCalendarStore,
          nativeMonthCalendarStore: self.nativeMonthCalendarStore,
          nativeComposerCalendarStore: self.nativeComposerCalendarStore,
          upcomingCalendarAgentClient: self.upcomingCalendarAgentClient,
          monthCalendarAgentClient: self.monthCalendarAgentClient,
          eventHub: self.eventHub
        )
      },
      Registration(id: "cpu", enabled: builtins.cpu.enabled) {
        CPUSparklineNativeWidget(
          config: builtins.cpu,
          widgetStore: self.widgetStore,
          eventHub: self.eventHub
        )
      },
    ]
  }

  /// Builds one native widget when its registration is enabled.
  private func makeWidgetIfEnabled(_ registration: Registration) -> NativeWidget? {
    guard registration.enabled else { return nil }
    return registration.makeWidget()
  }

  /// Applies the merged native widget event subscriptions to the event manager.
  private func applyNativeEventSubscriptions() {
    let subscriptions = widgets.reduce(into: Set<String>()) { result, widget in
      result.formUnion(widget.appEventSubscriptions)
    }

    logger.debug(
      "native widget event subscriptions",
      .field("subscriptions", subscriptions),
    )
    eventManager.setNativeSubscriptions(subscriptions)
  }

  /// Logs the current built-in widget enablement snapshot.
  private func logConfig(_ registrations: [Registration]) {
    logger.debug(
      "native widget config",
      .field("widgets", enabledWidgetSummary(registrations)),
      .field("calendar_popup_mode", snapshot.builtins.calendar.popupMode.rawValue),
    )
  }

  /// Returns a stable summary of all built-in widget enablement flags.
  private func enabledWidgetSummary(_ registrations: [Registration]) -> String {
    return
      registrations
      .map { registration in
        "\(registration.id)=\(registration.enabled)"
      }
      .joined(separator: ",")
  }

  /// Logs the final registered widget ids.
  private func logRegisteredWidgets() {
    logger.debug(
      "native widgets registered",
      .field("count", widgets.count),
      .field("ids", widgets.map(\.rootID).joined(separator: ",")),
    )
  }

  /// Starts all currently registered widgets.
  private func startWidgets() {
    for widget in widgets {
      logger.debug(
        "starting native widget",
        .field("id", widget.rootID),
      )
      widget.start()
    }
  }
}
