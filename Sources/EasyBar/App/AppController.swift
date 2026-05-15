import AppKit
import EasyBarShared
import Foundation

/// Main-actor app shell responsible for UI lifecycle and startup wiring.
@MainActor
final class AppController {
  /// Logger used for app-shell diagnostics.
  private let logger: ProcessLogger
  /// Coordinates runtime startup, refresh, reload, and shutdown.
  private let runtimeCoordinator: RuntimeCoordinator
  /// Converts process signals into graceful termination requests.
  private lazy var signalHandler = AppSignalHandler(logger: logger.child("signals")) {
    [weak self] in
    self?.requestTermination()
  }

  /// Whether the app shell has completed startup.
  private var started = false
  /// Shared shutdown task used to avoid duplicate cleanup.
  private var shutdownTask: Task<Void, Never>?
  /// Task that waits for graceful shutdown before terminating AppKit.
  private var terminationRequestTask: Task<Void, Never>?
  /// Whether AppKit termination should proceed immediately.
  private var forceImmediateTermination = false
  /// Controller for the main EasyBar panel.
  private var barWindowController: BarWindowController?

  /// Presenter for config load and reload errors.
  private let configErrorWindowController = ConfigErrorWindowController()
  /// Prevents multiple EasyBar instances from running at once.
  private let instanceGuard = SingleInstanceGuard()

  /// Creates the app shell with its process logger.
  init(logger: ProcessLogger) {
    self.logger = logger
    Self.bootstrapSharedDependencies(logger: logger.child("services"))
    self.runtimeCoordinator = RuntimeCoordinator(logger: logger.child("runtime"))
  }

  /// Starts the app shell and the actor-owned runtime.
  func start() {
    guard !started else { return }
    started = true

    switch instanceGuard.acquireLock(
      processName: "easybar",
      directory: Config.shared.lockDirectory
    ) {
    case .acquired:
      break

    case .alreadyRunning(let lockPath):
      logger.warn(
        "easybar already running",
        .field("lock_path", lockPath)
      )
      terminateApplication()

    case .failed(let lockPath, let reason):
      logger.error(
        "easybar failed to acquire instance lock",
        .field("lock_path", "\(lockPath)"),
        .field("reason", "\(reason)")
      )
      terminateApplication()
    }

    NSApp.setActivationPolicy(.accessory)

    configureLogging()
    logStartup()
    validateRequiredFonts()
    installWidgetEditorStub()
    setupBarWindowController()
    updateConfigErrorWindow()
    signalHandler.start()

    Task {
      await runtimeCoordinator.start()
    }
  }

  /// Stops the actor-owned runtime.
  func stop() {
    _ = ensureShutdownTask()
  }

  /// Stops the actor-owned runtime and waits for cleanup to finish.
  func stopAndWait() async {
    guard let shutdownTask = ensureShutdownTask() else { return }

    await shutdownTask.value
    self.shutdownTask = nil
  }

  /// Requests graceful shutdown, then terminates once cleanup is complete.
  func requestTermination() {
    guard !forceImmediateTermination else {
      NSApp.terminate(nil)
      return
    }

    guard terminationRequestTask == nil else { return }

    terminationRequestTask = Task { [weak self] in
      guard let self else { return }

      await self.stopAndWait()

      await MainActor.run {
        self.terminationRequestTask = nil
        self.forceImmediateTermination = true
        NSApp.terminate(nil)
      }
    }
  }

  /// Applies all UI-side work required after a config reload.
  func handlePostConfigReloadUI() {
    installWidgetEditorStub()
    barWindowController?.reloadLayout()
    updateConfigErrorWindow()
  }

  /// Keeps the config error window in sync with the current config state.
  func updateConfigErrorWindow() {
    guard let failureState = Config.shared.loadFailureState else {
      configErrorWindowController.close()
      return
    }

    configErrorWindowController.present(
      failureState: failureState,
      configPath: Config.shared.configPath,
      onReload: { [weak self] in
        guard let self else { return }

        Task {
          await self.runtimeCoordinator.reloadConfig()
        }
      }
    )
  }

  /// Returns whether AppKit termination should bypass graceful shutdown.
  var shouldTerminateImmediately: Bool {
    return forceImmediateTermination
  }

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    forceImmediateTermination = true
    NSApp.terminate(nil)
    fatalError("Application should have terminated")
  }

  /// Bootstraps all shared logger-owning services before runtime startup begins.
  private static func bootstrapSharedDependencies(logger: ProcessLogger) {
    LuaRuntime.bootstrap(logger: logger.child("lua"))
    EventManager.bootstrap(
      logger: logger.child("events"),
      luaRuntime: LuaRuntime.shared
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
  }

  /// Configures file logging from the current app config.
  private func configureLogging() {
    logger.configureRuntimeLogging(
      minimumLevel: Config.shared.loggingLevel,
      fileLoggingEnabled: Config.shared.loggingEnabled,
      fileLoggingPath: easyBarLogPath(in: Config.shared.loggingDirectory)
    )
  }

  /// Creates and presents the main bar window controller.
  private func setupBarWindowController() {
    let controller = BarWindowController(logger: logger.child("window"))
    controller.onRefresh = { [weak self] in
      guard let self else { return }

      Task {
        await self.runtimeCoordinator.refreshRuntime()
      }
    }
    controller.onReloadConfig = { [weak self] in
      guard let self else { return }

      Task {
        await self.runtimeCoordinator.reloadConfig()
      }
    }
    controller.onRestartLuaRuntime = { [weak self] in
      guard let self else { return }

      Task {
        await self.runtimeCoordinator.restartLuaRuntime()
      }
    }
    controller.present()
    barWindowController = controller
  }

  /// Logs one startup snapshot so service-vs-local differences are visible.
  private func logStartup() {
    logProcessStartup(
      processName: "easybar",
      configPath: Config.shared.configPath,
      socketPath: SharedRuntimeConfig.current.easyBarSocketPath,
      logger: logger
    )

    logConfigDetails()
    logScreenDetails()
    logEnvironmentDetails()
    logConfiguredEnvironment()
  }

  /// Logs config-derived startup details.
  private func logConfigDetails() {
    logger.info(
      "config details",
      .field("widgets_path", Config.shared.widgetsPath)
    )
    logger.info(
      "config details",
      .field("lua_path", Config.shared.luaPath)
    )
    logger.info(
      "config details",
      .field("lua_socket_path", Config.shared.luaSocketPath)
    )
    logger.info(
      "config details",
      .field("watch_config", Config.shared.watchConfigFile)
    )
    logger.info(
      "config details",
      .field("calendar_agent_enabled", Config.shared.calendarAgentEnabled),
      .field("socket", Config.shared.calendarAgentSocketPath)
    )
    logger.info(
      "config details",
      .field("network_agent_enabled", Config.shared.networkAgentEnabled),
      .field("socket", Config.shared.networkAgentSocketPath),
      .field("refresh_interval_seconds", Config.shared.networkAgentRefreshIntervalSeconds)
    )
    logger.info(
      "config details",
      .field("calendar_builtin_enabled", Config.shared.builtinCalendar.enabled),
      .field("popup_mode", Config.shared.builtinCalendar.popupMode.rawValue),
      .field("anchor_layout", Config.shared.builtinCalendar.anchor.layout.rawValue),
      .field("position", Config.shared.builtinCalendar.position.rawValue)
    )
    logger.info(
      "config details",
      .field("wifi_builtin_enabled", Config.shared.builtinWiFi.enabled),
      .field("position", Config.shared.builtinWiFi.position.rawValue)
    )
    logger.info(
      "config details",
      .field("bar_height", Config.shared.barHeight),
      .field("padding_x", Config.shared.barPaddingX),
      .field("extend_behind_notch", Config.shared.barExtendBehindNotch)
    )
  }

  /// Logs screen geometry visible at startup.
  private func logScreenDetails() {
    if let screen = NSScreen.main ?? NSScreen.screens.first {
      logger.info(
        "screen details",
        .field("screen_frame", NSStringFromRect(screen.frame)),
        .field("visible", NSStringFromRect(screen.visibleFrame))
      )
    } else {
      logger.warn("no screen available during startup logging")
    }
  }

  /// Logs relevant process environment overrides.
  private func logEnvironmentDetails() {
    let env = ProcessInfo.processInfo.environment
    let configOverride = env["\(SharedEnvironmentKeys.configPath)"] ?? ""
    let logLevel = env["\(SharedEnvironmentKeys.loggingLevel)"] ?? ""

    logger.info(
      "environment override",
      .field("key", SharedEnvironmentKeys.configPath),
      .field("value", configOverride.isEmpty ? "<unset>" : configOverride)
    )
    logger.info(
      "environment override",
      .field("key", SharedEnvironmentKeys.loggingLevel),
      .field("value", logLevel.isEmpty ? "<unset>" : logLevel)
    )
  }

  /// Logs the configured environment overrides passed to the Lua runtime.
  private func logConfiguredEnvironment() {
    let environment = Config.shared.appSection.environment

    guard !environment.isEmpty else {
      logger.info(
        "app env",
        .field("value", "<empty>")
      )
      return
    }

    for key in environment.keys.sorted() {
      let value = environment[key] ?? ""
      logger.info(
        "app env",
        .field("key", key),
        .field("value", value)
      )
    }
  }

  /// Logs whether required custom fonts are available at runtime.
  private func validateRequiredFonts() {
    validateFont(named: "Symbols Nerd Font Mono")
  }

  /// Logs one warning when a required font is missing.
  private func validateFont(named fontName: String) {
    if NSFont(name: fontName, size: 12) != nil {
      logger.info(
        "font available",
        .field("name", fontName)
      )
      return
    }

    logger.warn(
      "font missing; Nerd Font icons may render incorrectly or be clipped",
      .field("name", fontName)
    )
  }

  /// Installs the bundled Lua editor stub into the configured editor-stub path.
  private func installWidgetEditorStub() {
    guard let bundledStub = Bundle.module.url(forResource: "easybar_api", withExtension: "lua")
    else {
      logger.warn("easybar_api.lua not found in bundle resources")
      return
    }

    let installedStub = URL(fileURLWithPath: Config.shared.widgetEditorStubPath)

    do {
      let bundledData = try Data(contentsOf: bundledStub)
      let existingData = try? Data(contentsOf: installedStub)

      guard bundledData != existingData else {
        return
      }

      try FileManager.default.createDirectory(
        at: installedStub.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try bundledData.write(to: installedStub, options: .atomic)

      logger.info(
        "installed widget editor stub",
        .field("path", installedStub.path)
      )
    } catch {
      logger.warn(
        "failed to install widget editor stub",
        .field("error", error)
      )
    }
  }

  /// Starts one shared shutdown task when the app is still running.
  private func ensureShutdownTask() -> Task<Void, Never>? {
    if let shutdownTask {
      return shutdownTask
    }

    guard started else { return nil }
    started = false

    logger.info("easybar shutting down")
    signalHandler.stop()

    let shutdownTask = Task { [runtimeCoordinator] in
      await runtimeCoordinator.stop()
    }

    self.shutdownTask = shutdownTask
    return shutdownTask
  }
}
