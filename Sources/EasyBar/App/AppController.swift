import AppKit
import EasyBarShared
import Foundation

/// Main-actor app shell responsible for UI lifecycle and startup wiring.
@MainActor
final class AppController {
  private let logger: ProcessLogger
  private let runtimeCoordinator: RuntimeCoordinator
  private lazy var signalHandler = AppSignalHandler(logger: logger) { [weak self] in
    self?.requestTermination()
  }

  private var started = false
  private var shutdownTask: Task<Void, Never>?
  private var terminationRequestTask: Task<Void, Never>?
  private var forceImmediateTermination = false
  private var barWindowController: BarWindowController?

  private let configErrorWindowController = ConfigErrorWindowController()
  private let instanceGuard = SingleInstanceGuard()

  /// Creates the app shell with its process logger.
  init(logger: ProcessLogger) {
    self.logger = logger
    Self.bootstrapSharedDependencies(logger: logger)
    self.runtimeCoordinator = RuntimeCoordinator(logger: logger)
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
      logger.warn("easybar already running lock_path=\(lockPath)")
      terminateApplication()

    case .failed(let lockPath, let reason):
      logger.error(
        "easybar failed to acquire instance lock lock_path=\(lockPath) reason=\(reason)"
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
      configPath: Config.shared.configPath
    )
  }

  /// Returns whether AppKit termination should bypass graceful shutdown.
  var shouldTerminateImmediately: Bool {
    forceImmediateTermination
  }

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    forceImmediateTermination = true
    NSApp.terminate(nil)
    fatalError("Application should have terminated")
  }

  /// Bootstraps all shared logger-owning services before runtime startup begins.
  private static func bootstrapSharedDependencies(logger: ProcessLogger) {
    Config.shared.attachLogger(logger)

    LuaRuntime.bootstrap(logger: logger)
    EventManager.bootstrap(
      logger: logger,
      luaRuntime: LuaRuntime.shared
    )

    NativeWidgetRegistry.bootstrap(logger: logger)
    AeroSpaceService.bootstrap(logger: logger)
    CalendarAgentEventRelay.bootstrap(logger: logger)
    NetworkAgentClient.bootstrap(logger: logger)
    NativeWiFiStore.bootstrap(logger: logger)
    NativeMonthCalendarStore.bootstrap(logger: logger)
    NativeUpcomingCalendarStore.bootstrap(logger: logger)
    MonthCalendarAgentClient.bootstrap(logger: logger)
    UpcomingCalendarAgentClient.bootstrap(logger: logger)
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
    let controller = BarWindowController(logger: logger)
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
      socketSummary: formatLogFields("socket_path", SharedRuntimeConfig.current.easyBarSocketPath),
      loggingSummary: formatLogFields(
        "logging_enabled", logger.fileLoggingEnabled,
        "level", logger.minimumLevel.rawValue,
        "path", logger.fileLoggingPath
      ),
      write: logger.info
    )

    logConfigDetails()
    logScreenDetails()
    logEnvironmentDetails()
    logConfiguredEnvironment()
  }

  /// Logs config-derived startup details.
  private func logConfigDetails() {
    logger.info("config details widgets_path=\(Config.shared.widgetsPath)")
    logger.info("config details lua_path=\(Config.shared.luaPath)")
    logger.info("config details watch_config=\(Config.shared.watchConfigFile)")
    logger.info(
      "config details calendar_agent_enabled=\(Config.shared.calendarAgentEnabled) socket=\(Config.shared.calendarAgentSocketPath)"
    )
    logger.info(
      "config details network_agent_enabled=\(Config.shared.networkAgentEnabled) socket=\(Config.shared.networkAgentSocketPath) refresh_interval_seconds=\(Config.shared.networkAgentRefreshIntervalSeconds)"
    )
    logger.info(
      "config details calendar_builtin_enabled=\(Config.shared.builtinCalendar.enabled) popup_mode=\(Config.shared.builtinCalendar.popupMode.rawValue) anchor_layout=\(Config.shared.builtinCalendar.anchor.layout.rawValue) position=\(Config.shared.builtinCalendar.position.rawValue)"
    )
    logger.info(
      "config details wifi_builtin_enabled=\(Config.shared.builtinWiFi.enabled) position=\(Config.shared.builtinWiFi.position.rawValue)"
    )
    logger.info(
      "config details bar_height=\(Config.shared.barHeight) padding_x=\(Config.shared.barPaddingX) extend_behind_notch=\(Config.shared.barExtendBehindNotch)"
    )
  }

  /// Logs screen geometry visible at startup.
  private func logScreenDetails() {
    if let screen = NSScreen.main ?? NSScreen.screens.first {
      logger.info(
        "screen details screen_frame=\(NSStringFromRect(screen.frame)) visible=\(NSStringFromRect(screen.visibleFrame))"
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
      "environment \(SharedEnvironmentKeys.configPath)=\(configOverride.isEmpty ? "<unset>" : configOverride)"
    )
    logger.info(
      "environment \(SharedEnvironmentKeys.loggingLevel)=\(logLevel.isEmpty ? "<unset>" : logLevel)"
    )
  }

  /// Logs the configured environment overrides passed to the Lua runtime.
  private func logConfiguredEnvironment() {
    let environment = Config.shared.appSection.environment

    guard !environment.isEmpty else {
      logger.info("app env value=<empty>")
      return
    }

    for key in environment.keys.sorted() {
      let value = environment[key] ?? ""
      logger.info("app env \(key)=\(value)")
    }
  }

  /// Logs whether required custom fonts are available at runtime.
  private func validateRequiredFonts() {
    validateFont(named: "Symbols Nerd Font Mono")
  }

  /// Logs one warning when a required font is missing.
  private func validateFont(named fontName: String) {
    if NSFont(name: fontName, size: 12) != nil {
      logger.info("font available name=\(fontName)")
      return
    }

    logger.warn(
      "font missing name=\(fontName); Nerd Font icons may render incorrectly or be clipped"
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
      logger.info("installed widget editor stub path=\(installedStub.path)")
    } catch {
      logger.warn("failed to install widget editor stub error=\(error)")
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
