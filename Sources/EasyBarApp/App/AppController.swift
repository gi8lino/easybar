import AppKit
import CryptoKit
import EasyBarShared
import Foundation

/// Main-actor app shell responsible for UI lifecycle and startup wiring.
@MainActor
final class AppController {
  /// Logger used for app-shell diagnostics.
  private let logger: ProcessLogger
  /// Explicit app-wide service graph bootstrapped during startup wiring.
  private let services: AppServices
  /// Coordinates runtime startup, refresh, reload, and shutdown.
  private let runtimeCoordinator: RuntimeCoordinator
  /// Callback used to ask the app delegate to start graceful termination.
  private let requestAppTermination: () -> Void
  /// Converts process signals into graceful termination requests.
  private lazy var signalHandler = AppSignalHandler(logger: logger.child("signals")) {
    [weak self] in
    self?.requestAppTermination()
  }

  /// Whether the app shell has completed startup.
  private var started = false
  /// Shared shutdown task used to avoid duplicate cleanup.
  private var shutdownTask: Task<Void, Never>?
  /// Task that waits for graceful shutdown before terminating AppKit.
  private var terminationRequestTask: Task<Void, Never>?
  /// Controller for the main EasyBar panel.
  private var barWindowController: BarWindowController?
  /// Observer token for runtime config reload completion notifications.
  private var configReloadObserver: NSObjectProtocol?

  /// Presenter for config load and reload errors.
  private let configErrorWindowController = ConfigErrorWindowController()
  /// Prevents multiple EasyBar instances from running at once.
  private let instanceGuard = SingleInstanceGuard()

  /// Creates the app shell with its process logger.
  init(
    logger: ProcessLogger,
    requestAppTermination: @escaping () -> Void
  ) {
    self.logger = logger
    self.requestAppTermination = requestAppTermination
    self.services = Self.bootstrapSharedDependencies(logger: logger.child("services"))
    self.runtimeCoordinator = RuntimeCoordinator(
      logger: logger.child("runtime"),
      services: services
    )
  }

  /// Starts the app shell and the actor-owned runtime.
  @discardableResult
  func start() -> Bool {
    guard !started else {
      writeEasyBarBootstrapLog("AppController.start skipped because app is already started")
      return true
    }

    writeEasyBarBootstrapLog("AppController.start begin")
    started = true

    writeEasyBarBootstrapLog("loading initial config")
    if let error = services.config.loadInitialState() {
      writeEasyBarBootstrapErrorLog(
        "initial config load failed config_path=\(services.config.configPath) error=\(error)"
      )
      logger.error(
        "initial config load failed",
        .field("config_path", services.config.configPath),
        .field("error", "\(error)")
      )
    } else {
      writeEasyBarBootstrapLog("initial config loaded path=\(services.config.configPath)")
    }

    writeEasyBarBootstrapLog("applying runtime configuration")
    services.applyRuntimeConfiguration(services.config.snapshot())
    writeEasyBarBootstrapLog("runtime configuration applied")

    writeEasyBarBootstrapLog("acquiring single instance lock")
    guard acquireInstanceLock() else {
      writeEasyBarBootstrapErrorLog("single instance lock acquisition failed")
      started = false
      return false
    }
    writeEasyBarBootstrapLog("single instance lock acquired")

    NSApp.setActivationPolicy(.accessory)
    writeEasyBarBootstrapLog("activation policy set to accessory")

    writeEasyBarBootstrapLog("configuring process logging")
    configureLogging()
    writeEasyBarBootstrapLog("process logging configured")

    logStartup()
    validateRequiredFonts()
    installWidgetEditorStub()

    writeEasyBarBootstrapLog("presenting bar window")
    setupBarWindowController()
    writeEasyBarBootstrapLog("bar window presented")

    installConfigReloadObserver()
    updateConfigErrorWindow()
    signalHandler.start()
    writeEasyBarBootstrapLog("signal handler started")

    Task {
      await runtimeCoordinator.start()
    }
    writeEasyBarBootstrapLog("runtime coordinator start scheduled")

    return true
  }

  /// Acquires the single-instance lock for the main EasyBar process.
  private func acquireInstanceLock() -> Bool {
    AppShellSupport.acquireInstanceLock(
      instanceGuard: instanceGuard,
      processName: "easybar",
      directory: services.config.lockDirectory,
      logger: logger,
      alreadyRunningMessage: "easybar already running",
      failureMessage: "easybar failed to acquire instance lock"
    )
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

  /// Requests graceful shutdown, then calls the completion once cleanup is complete.
  func requestTermination(completion: @escaping @MainActor () -> Void) {
    guard terminationRequestTask == nil else { return }

    terminationRequestTask = Task { [weak self] in
      guard let self else { return }

      await self.stopAndWait()

      await MainActor.run {
        self.terminationRequestTask = nil
        completion()
      }
    }
  }

  /// Applies all UI-side work required after a config reload.
  func handlePostConfigReloadUI() {
    installWidgetEditorStub()
    barWindowController?.reloadLayout()
    updateConfigErrorWindow()
  }

  /// Observes runtime config reload completion so UI stays in sync.
  private func installConfigReloadObserver() {
    guard configReloadObserver == nil else { return }

    configReloadObserver = NotificationCenter.default.addObserver(
      forName: .easyBarConfigReloadDidFinish,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.handlePostConfigReloadUI()
      }
    }
  }

  /// Keeps the config error window in sync with the current config state.
  func updateConfigErrorWindow() {
    guard let failureState = services.config.loadFailureState else {
      configErrorWindowController.close()
      return
    }

    configErrorWindowController.present(
      failureState: failureState,
      configPath: services.config.configPath,
      onReload: { [weak self] in
        guard let self else { return }

        Task {
          await self.runtimeCoordinator.reloadConfig()
        }
      }
    )
  }

  /// Bootstraps all shared logger-owning services before runtime startup begins.
  private static func bootstrapSharedDependencies(logger: ProcessLogger) -> AppServices {
    AppServices.bootstrap(logger: logger)
  }

  /// Configures file logging from the current app config.
  private func configureLogging() {
    AppShellSupport.configureLogging(
      logger: logger,
      minimumLevel: services.config.loggingLevel,
      fileLoggingEnabled: services.config.loggingEnabled,
      loggingDirectory: services.config.loggingDirectory,
      logFileName: "easybar.out"
    )
  }

  /// Creates and presents the main bar window controller.
  private func setupBarWindowController() {
    let controller = BarWindowController(
      logger: logger.child("window"),
      configStore: services.configSnapshotStore
    )
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
      configPath: services.config.configPath,
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
      .field("widgets_path", services.config.widgetsPath)
    )
    logger.info(
      "config details",
      .field("lua_path", services.config.luaPath)
    )
    logger.info(
      "config details",
      .field("lua_socket_path", services.config.luaSocketPath)
    )
    logger.info(
      "config details",
      .field("watch_config", services.config.watchConfigFile)
    )
    logger.info(
      "config details",
      .field("calendar_agent_enabled", services.config.calendarAgentEnabled),
      .field("socket", services.config.calendarAgentSocketPath)
    )
    logger.info(
      "config details",
      .field("network_agent_enabled", services.config.networkAgentEnabled),
      .field("socket", services.config.networkAgentSocketPath),
      .field("refresh_interval_seconds", services.config.networkAgentRefreshIntervalSeconds)
    )
    logger.info(
      "config details",
      .field("calendar_builtin_enabled", services.config.builtinCalendar.enabled),
      .field("popup_mode", services.config.builtinCalendar.popupMode.rawValue),
      .field("anchor_layout", services.config.builtinCalendar.anchor.layout.rawValue),
      .field("position", services.config.builtinCalendar.position.rawValue)
    )
    logger.info(
      "config details",
      .field("wifi_builtin_enabled", services.config.builtinWiFi.enabled),
      .field("position", services.config.builtinWiFi.position.rawValue)
    )
    logger.info(
      "config details",
      .field("bar_height", services.config.barHeight),
      .field("padding_x", services.config.barPaddingX),
      .field("extend_behind_notch", services.config.barExtendBehindNotch)
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
    let environment = services.config.appSection.environment

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

    let installedStub = URL(fileURLWithPath: services.config.widgetEditorStubPath)

    do {
      let bundledData = try Data(contentsOf: bundledStub)
      let existingData = try? Data(contentsOf: installedStub)
      let bundledHash = sha256Hex(for: bundledData)
      let existingHash = existingData.map(sha256Hex)

      guard bundledHash != existingHash else {
        return
      }

      try FileManager.default.createDirectory(
        at: installedStub.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try bundledData.write(to: installedStub, options: .atomic)

      logger.info(
        "installed widget editor stub",
        .field("bundled_hash", bundledHash),
        .field("previous_hash", existingHash ?? "<missing>"),
        .field("path", installedStub.path)
      )
    } catch {
      logger.warn(
        "failed to install widget editor stub",
        .field("error", error)
      )
    }
  }

  /// Returns the SHA-256 digest for one Lua editor stub payload.
  private func sha256Hex(for data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
