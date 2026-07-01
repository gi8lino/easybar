import EasyBarShared

/// Explicitly owned app services used by the app shell and runtime coordinator.
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

  @MainActor
  static func bootstrap(logger: ProcessLogger) -> AppServices {
    let configServices = makeConfigServices()
    let metricsCoordinator = MetricsCoordinator()
    let luaRuntime = LuaRuntime(logger: logger.child("lua"))
    let eventServices = makeEventServices(
      logger: logger.child("events"),
      luaRuntime: luaRuntime
    )
    let nativeServices = makeNativeServices(
      logger: logger,
      snapshot: configServices.bootstrapSnapshot,
      eventManager: eventServices.eventManager
    )
    let agentServices = makeAgentServices(
      logger: logger,
      snapshot: configServices.bootstrapSnapshot
    )

    let services = AppServices(
      config: configServices.config,
      configManager: configServices.configManager,
      configSnapshotStore: configServices.configSnapshotStore,
      luaRuntime: luaRuntime,
      eventHub: eventServices.eventHub,
      eventManager: eventServices.eventManager,
      systemEvents: eventServices.systemEvents,
      powerEvents: eventServices.powerEvents,
      timerEvents: eventServices.timerEvents,
      volumeEvents: eventServices.volumeEvents,
      widgetStore: nativeServices.widgetStore,
      nativeWidgetRegistry: nativeServices.nativeWidgetRegistry,
      aeroSpaceService: nativeServices.aeroSpaceService,
      calendarAgentEventRelay: agentServices.calendarAgentEventRelay,
      networkAgentClient: agentServices.networkAgentClient,
      nativeWiFiStore: nativeServices.nativeWiFiStore,
      nativeMonthCalendarStore: nativeServices.nativeMonthCalendarStore,
      nativeUpcomingCalendarStore: nativeServices.nativeUpcomingCalendarStore,
      nativeComposerCalendarStore: nativeServices.nativeComposerCalendarStore,
      monthCalendarAgentClient: agentServices.monthCalendarAgentClient,
      upcomingCalendarAgentClient: agentServices.upcomingCalendarAgentClient,
      composerCalendarAgentClient: agentServices.composerCalendarAgentClient,
      metricsCoordinator: metricsCoordinator
    )

    services.installSharedCompatibilityLayer()
    return services
  }

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

  @MainActor
  private func installSharedCompatibilityLayer() {
    MetricsCoordinator.shared = metricsCoordinator
    EventHub.shared = eventHub
    EventManager.shared = eventManager
    SystemEvents.shared = systemEvents
    PowerEvents.shared = powerEvents
    TimerEvents.shared = timerEvents
    VolumeEvents.shared = volumeEvents
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

  @MainActor
  private static func makeConfigServices() -> ConfigServices {
    let config = Config.makeUnloadedConfig()
    let bootstrapSnapshot = config.snapshot()

    return ConfigServices(
      config: config,
      bootstrapSnapshot: bootstrapSnapshot,
      configSnapshotStore: ConfigSnapshotStore(snapshot: bootstrapSnapshot),
      configManager: ConfigManager(config: config)
    )
  }

  @MainActor
  private static func makeEventServices(logger: ProcessLogger, luaRuntime: LuaRuntime)
    -> EventServices
  {
    let eventHub = EventHub(
      logger: logger.child("hub"),
      luaRuntime: luaRuntime
    )

    return EventServices(
      eventHub: eventHub,
      eventManager: EventManager(logger: logger.child("manager")),
      systemEvents: SystemEvents(logger: logger.child("system")),
      powerEvents: PowerEvents(logger: logger.child("power")),
      timerEvents: TimerEvents(logger: logger.child("timer")),
      volumeEvents: VolumeEvents(logger: logger.child("volume"))
    )
  }

  @MainActor
  private static func makeNativeServices(
    logger: ProcessLogger,
    snapshot: ConfigSnapshot,
    eventManager: EventManager
  )
    -> NativeServices
  {
    let widgetStore = WidgetStore()
    let aeroSpaceService = AeroSpaceService(logger: logger.child("aerospace"))

    return NativeServices(
      widgetStore: widgetStore,
      nativeWidgetRegistry: NativeWidgetRegistry(
        logger: logger.child("widgets"),
        snapshot: snapshot,
        widgetStore: widgetStore,
        eventManager: eventManager,
        aeroSpaceService: aeroSpaceService
      ),
      aeroSpaceService: aeroSpaceService,
      nativeWiFiStore: NativeWiFiStore(logger: logger.child("wifi_store")),
      nativeMonthCalendarStore: NativeMonthCalendarStore(logger: logger.child("month_store")),
      nativeUpcomingCalendarStore: NativeUpcomingCalendarStore(
        logger: logger.child("upcoming_store")
      ),
      nativeComposerCalendarStore: NativeComposerCalendarStore(
        logger: logger.child("composer_calendar_store")
      )
    )
  }

  @MainActor
  private static func makeAgentServices(logger: ProcessLogger, snapshot: ConfigSnapshot)
    -> AgentServices
  {
    AgentServices(
      calendarAgentEventRelay: CalendarAgentEventRelay(logger: logger.child("calendar_relay")),
      networkAgentClient: NetworkAgentClient(
        logger: logger.child("network_agent"),
        config: snapshot.networkAgent
      ),
      monthCalendarAgentClient: MonthCalendarAgentClient(
        logger: logger.child("month_agent"),
        calendarAgentConfig: snapshot.calendarAgent,
        calendarConfig: snapshot.builtins.calendar
      ),
      upcomingCalendarAgentClient: UpcomingCalendarAgentClient(
        logger: logger.child("upcoming_agent"),
        calendarAgentConfig: snapshot.calendarAgent,
        calendarConfig: snapshot.builtins.calendar
      ),
      composerCalendarAgentClient: ComposerCalendarAgentClient(
        logger: logger.child("composer_calendar_agent"),
        calendarAgentConfig: snapshot.calendarAgent
      )
    )
  }
}

/// Config-related services built before loading the user's config file.
private struct ConfigServices {
  let config: Config
  let bootstrapSnapshot: ConfigSnapshot
  let configSnapshotStore: ConfigSnapshotStore
  let configManager: ConfigManager
}

/// Event services that feed native widgets and Lua widgets.
private struct EventServices {
  let eventHub: EventHub
  let eventManager: EventManager
  let systemEvents: SystemEvents
  let powerEvents: PowerEvents
  let timerEvents: TimerEvents
  let volumeEvents: VolumeEvents
}

/// UI-facing services and stores for native widgets.
private struct NativeServices {
  let widgetStore: WidgetStore
  let nativeWidgetRegistry: NativeWidgetRegistry
  let aeroSpaceService: AeroSpaceService
  let nativeWiFiStore: NativeWiFiStore
  let nativeMonthCalendarStore: NativeMonthCalendarStore
  let nativeUpcomingCalendarStore: NativeUpcomingCalendarStore
  let nativeComposerCalendarStore: NativeComposerCalendarStore
}

/// Helper-agent clients and relays.
private struct AgentServices {
  let calendarAgentEventRelay: CalendarAgentEventRelay
  let networkAgentClient: NetworkAgentClient
  let monthCalendarAgentClient: MonthCalendarAgentClient
  let upcomingCalendarAgentClient: UpcomingCalendarAgentClient
  let composerCalendarAgentClient: ComposerCalendarAgentClient
}
