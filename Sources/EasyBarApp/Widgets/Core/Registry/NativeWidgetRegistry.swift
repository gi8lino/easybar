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
  private let aeroSpaceService: AeroSpaceService
  private let nativeGroupRegistry: NativeGroupRegistry
  private var snapshot: ConfigSnapshot
  private var widgets: [NativeWidget] = []

  init(
    logger: ProcessLogger,
    snapshot: ConfigSnapshot,
    widgetStore: WidgetStore,
    eventManager: EventManager,
    aeroSpaceService: AeroSpaceService
  ) {
    self.logger = logger
    self.snapshot = snapshot
    self.widgetStore = widgetStore
    self.eventManager = eventManager
    self.aeroSpaceService = aeroSpaceService
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
    logger.info("native widget registry registerAll begin")

    stopAll()

    let registrations = registrations()

    logger.info("registering native widgets")
    logConfig(registrations)

    nativeGroupRegistry.reload(groups: snapshot.builtins.groups)
    widgets = makeEnabledWidgets(from: registrations)

    logRegisteredWidgets()

    applyNativeEventSubscriptions()
    startWidgets()

    logger.info("native widget registry registerAll end")
  }

  /// Stops and clears all widgets.
  private func stopAll() {
    if !widgets.isEmpty {
      logger.info(
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
        BatteryNativeWidget(config: builtins.battery, widgetStore: self.widgetStore)
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
        VolumeSliderNativeWidget(config: builtins.volume, widgetStore: self.widgetStore)
      },
      Registration(id: "wifi", enabled: builtins.wifi.enabled) {
        WiFiNativeWidget(
          config: builtins.wifi,
          networkAgentConfig: networkAgent,
          widgetStore: self.widgetStore,
          networkAgentClient: NetworkAgentClient.shared,
          nativeWiFiStore: NativeWiFiStore.shared
        )
      },
      Registration(id: "date", enabled: builtins.date.enabled) {
        DateNativeWidget(config: builtins.date, widgetStore: self.widgetStore)
      },
      Registration(id: "time", enabled: builtins.time.enabled) {
        TimeNativeWidget(config: builtins.time, widgetStore: self.widgetStore)
      },
      Registration(id: "calendar", enabled: builtins.calendar.enabled) {
        CalendarNativeWidget(
          config: builtins.calendar,
          calendarAgentConfig: calendarAgent,
          widgetStore: self.widgetStore,
          nativeUpcomingCalendarStore: NativeUpcomingCalendarStore.shared,
          nativeMonthCalendarStore: NativeMonthCalendarStore.shared,
          nativeComposerCalendarStore: NativeComposerCalendarStore.shared,
          upcomingCalendarAgentClient: UpcomingCalendarAgentClient.shared,
          monthCalendarAgentClient: MonthCalendarAgentClient.shared
        )
      },
      Registration(id: "cpu", enabled: builtins.cpu.enabled) {
        CPUSparklineNativeWidget(config: builtins.cpu, widgetStore: self.widgetStore)
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
    logger.info(
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
    logger.info(
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
