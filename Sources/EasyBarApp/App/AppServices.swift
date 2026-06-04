import EasyBarShared

/// Explicitly owned app services used by the app shell and runtime coordinator.
///
/// AppServices is the production dependency graph. The legacy `*.shared` globals
/// are updated from this graph as a compatibility layer for older UI and widget
/// code that has not been dependency-injected yet.
struct AppServices {
  let config: Config
  let configManager: ConfigManager
  let configSnapshotStore: ConfigSnapshotStore
  let luaRuntime: LuaRuntime
  let eventHub: EventHub
  let eventManager: EventManager
  let systemEvents: SystemEvents
  let powerEvents: PowerEvents
  let timerEvents: TimerEvents
  let volumeEvents: VolumeEvents
  let widgetStore: WidgetStore
  let nativeWidgetRegistry: NativeWidgetRegistry
  let aeroSpaceService: AeroSpaceService
  let calendarAgentEventRelay: CalendarAgentEventRelay
  let networkAgentClient: NetworkAgentClient
  let nativeWiFiStore: NativeWiFiStore
  let nativeMonthCalendarStore: NativeMonthCalendarStore
  let nativeUpcomingCalendarStore: NativeUpcomingCalendarStore
  let nativeComposerCalendarStore: NativeComposerCalendarStore
  let monthCalendarAgentClient: MonthCalendarAgentClient
  let upcomingCalendarAgentClient: UpcomingCalendarAgentClient
  let composerCalendarAgentClient: ComposerCalendarAgentClient
  let metricsCoordinator: MetricsCoordinator

  /// Creates the production app dependency graph.
  @MainActor
  static func bootstrap(logger: ProcessLogger) -> AppServices {
    let config = Config.makeUnloadedConfig()
    let bootstrapSnapshot = config.snapshot()
    let configSnapshotStore = ConfigSnapshotStore(snapshot: bootstrapSnapshot)
    let configManager = ConfigManager(config: config)
    let metricsCoordinator = MetricsCoordinator()
    let luaRuntime = LuaRuntime(logger: logger.child("lua"))

    let eventsLogger = logger.child("events")
    let eventHub = EventHub(
      logger: eventsLogger.child("hub"),
      luaRuntime: luaRuntime
    )
    let systemEvents = SystemEvents(logger: eventsLogger.child("system"))
    let powerEvents = PowerEvents(logger: eventsLogger.child("power"))
    let timerEvents = TimerEvents(logger: eventsLogger.child("timer"))
    let volumeEvents = VolumeEvents(logger: eventsLogger.child("volume"))
    let eventManager = EventManager(logger: eventsLogger.child("manager"))

    let widgetStore = WidgetStore()
    let nativeWidgetRegistry = NativeWidgetRegistry(
      logger: logger.child("widgets"),
      snapshot: bootstrapSnapshot
    )
    let aeroSpaceService = AeroSpaceService(logger: logger.child("aerospace"))
    let calendarAgentEventRelay = CalendarAgentEventRelay(logger: logger.child("calendar_relay"))
    let networkAgentClient = NetworkAgentClient(
      logger: logger.child("network_agent"),
      config: bootstrapSnapshot.networkAgent
    )
    let nativeWiFiStore = NativeWiFiStore(logger: logger.child("wifi_store"))
    let nativeMonthCalendarStore = NativeMonthCalendarStore(logger: logger.child("month_store"))
    let nativeUpcomingCalendarStore = NativeUpcomingCalendarStore(
      logger: logger.child("upcoming_store")
    )
    let nativeComposerCalendarStore = NativeComposerCalendarStore(
      logger: logger.child("composer_calendar_store")
    )
    let monthCalendarAgentClient = MonthCalendarAgentClient(
      logger: logger.child("month_agent"),
      calendarAgentConfig: bootstrapSnapshot.calendarAgent,
      calendarConfig: bootstrapSnapshot.builtins.calendar
    )
    let upcomingCalendarAgentClient = UpcomingCalendarAgentClient(
      logger: logger.child("upcoming_agent"),
      calendarAgentConfig: bootstrapSnapshot.calendarAgent,
      calendarConfig: bootstrapSnapshot.builtins.calendar
    )
    let composerCalendarAgentClient = ComposerCalendarAgentClient(
      logger: logger.child("composer_calendar_agent"),
      calendarAgentConfig: bootstrapSnapshot.calendarAgent
    )

    let services = AppServices(
      config: config,
      configManager: configManager,
      configSnapshotStore: configSnapshotStore,
      luaRuntime: luaRuntime,
      eventHub: eventHub,
      eventManager: eventManager,
      systemEvents: systemEvents,
      powerEvents: powerEvents,
      timerEvents: timerEvents,
      volumeEvents: volumeEvents,
      widgetStore: widgetStore,
      nativeWidgetRegistry: nativeWidgetRegistry,
      aeroSpaceService: aeroSpaceService,
      calendarAgentEventRelay: calendarAgentEventRelay,
      networkAgentClient: networkAgentClient,
      nativeWiFiStore: nativeWiFiStore,
      nativeMonthCalendarStore: nativeMonthCalendarStore,
      nativeUpcomingCalendarStore: nativeUpcomingCalendarStore,
      nativeComposerCalendarStore: nativeComposerCalendarStore,
      monthCalendarAgentClient: monthCalendarAgentClient,
      upcomingCalendarAgentClient: upcomingCalendarAgentClient,
      composerCalendarAgentClient: composerCalendarAgentClient,
      metricsCoordinator: metricsCoordinator
    )

    services.installSharedCompatibilityLayer()
    return services
  }

  /// Applies one immutable config snapshot to owned runtime services.
  @MainActor
  func applyRuntimeConfiguration(_ snapshot: ConfigSnapshot) {
    configSnapshotStore.apply(snapshot)
    networkAgentClient.updateConfiguration(snapshot.networkAgent)
    monthCalendarAgentClient.updateConfiguration(
      calendarAgentConfig: snapshot.calendarAgent,
      calendarConfig: snapshot.builtins.calendar
    )
    upcomingCalendarAgentClient.updateConfiguration(
      calendarAgentConfig: snapshot.calendarAgent,
      calendarConfig: snapshot.builtins.calendar
    )
    composerCalendarAgentClient.updateConfiguration(snapshot.calendarAgent)
  }

  /// Mirrors owned service instances into legacy shared accessors.
  @MainActor
  private func installSharedCompatibilityLayer() {
    ConfigManager.shared = configManager
    MetricsCoordinator.shared = metricsCoordinator
    LuaRuntime.shared = luaRuntime
    EventHub.shared = eventHub
    EventManager.shared = eventManager
    SystemEvents.shared = systemEvents
    PowerEvents.shared = powerEvents
    TimerEvents.shared = timerEvents
    VolumeEvents.shared = volumeEvents
    WidgetStore.shared = widgetStore
    NativeWidgetRegistry.shared = nativeWidgetRegistry
    AeroSpaceService.shared = aeroSpaceService
    CalendarAgentEventRelay.shared = calendarAgentEventRelay
    NetworkAgentClient.shared = networkAgentClient
    NativeWiFiStore.shared = nativeWiFiStore
    NativeMonthCalendarStore.shared = nativeMonthCalendarStore
    NativeUpcomingCalendarStore.shared = nativeUpcomingCalendarStore
    NativeComposerCalendarStore.shared = nativeComposerCalendarStore
    MonthCalendarAgentClient.shared = monthCalendarAgentClient
    UpcomingCalendarAgentClient.shared = upcomingCalendarAgentClient
    ComposerCalendarAgentClient.shared = composerCalendarAgentClient
  }
}
