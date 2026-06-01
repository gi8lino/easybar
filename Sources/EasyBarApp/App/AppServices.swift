import EasyBarShared

/// Explicitly bootstrapped app services used by the app shell and runtime coordinator.
struct AppServices {
  let config: Config
  let luaRuntime: LuaRuntime
  let eventHub: EventHub
  let eventManager: EventManager
  let nativeWidgetRegistry: NativeWidgetRegistry
  let aeroSpaceService: AeroSpaceService
  let calendarAgentEventRelay: CalendarAgentEventRelay
  let networkAgentClient: NetworkAgentClient
  let nativeWiFiStore: NativeWiFiStore
  let nativeMonthCalendarStore: NativeMonthCalendarStore
  let nativeUpcomingCalendarStore: NativeUpcomingCalendarStore
  let monthCalendarAgentClient: MonthCalendarAgentClient
  let upcomingCalendarAgentClient: UpcomingCalendarAgentClient

  /// Bootstraps shared service instances and captures the resulting dependency graph.
  @MainActor
  static func bootstrap(logger: ProcessLogger) -> AppServices {
    LuaRuntime.bootstrap(logger: logger.child("lua"))
    let bootstrappedLuaRuntime = LuaRuntime.shared

    EventManager.bootstrap(
      logger: logger.child("events"),
      luaRuntime: bootstrappedLuaRuntime
    )

    NativeWidgetRegistry.bootstrap(logger: logger.child("widgets"))
    AeroSpaceService.bootstrap(logger: logger.child("aerospace"))
    CalendarAgentEventRelay.bootstrap(logger: logger.child("calendar_relay"))
    NetworkAgentClient.bootstrap(logger: logger.child("network_agent"))
    NativeWiFiStore.bootstrap(logger: logger.child("wifi_store"))
    NativeMonthCalendarStore.bootstrap(logger: logger.child("month_store"))
    NativeUpcomingCalendarStore.bootstrap(logger: logger.child("upcoming_store"))
    MonthCalendarAgentClient.bootstrap(logger: logger.child("month_agent"))
    UpcomingCalendarAgentClient.bootstrap(logger: logger.child("upcoming_agent"))

    return AppServices(
      config: Config.shared,
      luaRuntime: LuaRuntime.shared,
      eventHub: EventHub.shared,
      eventManager: EventManager.shared,
      nativeWidgetRegistry: NativeWidgetRegistry.shared,
      aeroSpaceService: AeroSpaceService.shared,
      calendarAgentEventRelay: CalendarAgentEventRelay.shared,
      networkAgentClient: NetworkAgentClient.shared,
      nativeWiFiStore: NativeWiFiStore.shared,
      nativeMonthCalendarStore: NativeMonthCalendarStore.shared,
      nativeUpcomingCalendarStore: NativeUpcomingCalendarStore.shared,
      monthCalendarAgentClient: MonthCalendarAgentClient.shared,
      upcomingCalendarAgentClient: UpcomingCalendarAgentClient.shared
    )
  }
}
