import AppKit
import EasyBarShared
import Foundation

/// Main-actor app shell responsible for UI lifecycle and startup wiring.
@MainActor
final class AppController {
  static let shared = AppController()

  private var started = false
  private var shutdownTask: Task<Void, Never>?
  private var terminationRequestTask: Task<Void, Never>?
  private var forceImmediateTermination = false
  private var barWindowController: BarWindowController?
  private let configErrorWindowController = ConfigErrorWindowController()
  private let instanceGuard = SingleInstanceGuard()
  private let signalHandler = AppSignalHandler()

  private init() {}

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
      easybarLog.warn("easybar already running lock_path=\(lockPath)")
      terminateApplication()

    case .failed(let lockPath, let reason):
      easybarLog.error(
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
      await RuntimeCoordinator.shared.start()
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

  /// Reloads the visible bar layout.
  func reloadBarLayout() {
    barWindowController?.reloadLayout()
  }

  /// Applies all UI-side work required after a config reload.
  func handlePostConfigReloadUI() {
    installWidgetEditorStub()
    reloadBarLayout()
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

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    forceImmediateTermination = true
    NSApp.terminate(nil)
    fatalError("Application should have terminated")
  }

  /// Returns whether AppKit termination should bypass graceful shutdown.
  var shouldTerminateImmediately: Bool {
    forceImmediateTermination
  }

  /// Configures file logging from the current app config.
  private func configureLogging() {
    easybarLog.configureRuntimeLogging(
      minimumLevel: Config.shared.loggingLevel,
      fileLoggingEnabled: Config.shared.loggingEnabled,
      fileLoggingPath: easyBarLogPath(in: Config.shared.loggingDirectory)
    )
  }

  /// Creates and presents the main bar window controller.
  private func setupBarWindowController() {
    let controller = BarWindowController()
    controller.onRefresh = {
      Task {
        await RuntimeCoordinator.shared.refreshRuntime()
      }
    }
    controller.onReloadConfig = {
      Task {
        await RuntimeCoordinator.shared.reloadConfig()
      }
    }
    controller.onRestartLuaRuntime = {
      Task {
        await RuntimeCoordinator.shared.restartLuaRuntime()
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
      socketSummary: "socket path=\(SharedRuntimeConfig.current.easyBarSocketPath)",
      loggingSummary:
        """
        logging enabled=\(easybarLog.fileLoggingEnabled)
        level=\(easybarLog.minimumLevel.rawValue)
        path=\(easybarLog.fileLoggingPath)
        """,
      write: easybarLog.info
    )

    logConfigDetails()
    logScreenDetails()
    logEnvironmentDetails()
    logConfiguredEnvironment()
  }

  /// Logs config-derived startup details.
  private func logConfigDetails() {
    easybarLog.info("widgets path=\(Config.shared.widgetsPath)")
    easybarLog.info("lua path=\(Config.shared.luaPath)")
    easybarLog.info("watch config=\(Config.shared.watchConfigFile)")
    easybarLog.info(
      """
      calendar agent enabled=\(Config.shared.calendarAgentEnabled)
      socket=\(Config.shared.calendarAgentSocketPath)
      """)
    easybarLog.info(
      """
      network agent enabled=\(Config.shared.networkAgentEnabled)
      socket=\(Config.shared.networkAgentSocketPath)
      refresh_interval_seconds=\(Config.shared.networkAgentRefreshIntervalSeconds)
      """)
    easybarLog.info(
      """
      calendar builtin enabled=\(Config.shared.builtinCalendar.enabled)
      popup_mode=\(Config.shared.builtinCalendar.popupMode.rawValue)
      anchor_layout=\(Config.shared.builtinCalendar.anchor.layout.rawValue)
      position=\(Config.shared.builtinCalendar.position.rawValue)
      """)
    easybarLog.info(
      """
      wifi builtin enabled=\(Config.shared.builtinWiFi.enabled)
      position=\(Config.shared.builtinWiFi.position.rawValue)
      """)
    easybarLog.info(
      """
      bar height=\(Config.shared.barHeight)
      padding_x=\(Config.shared.barPaddingX)
      extend_behind_notch=\(Config.shared.barExtendBehindNotch)
      """)
  }

  /// Logs screen geometry visible at startup.
  private func logScreenDetails() {
    if let screen = NSScreen.main ?? NSScreen.screens.first {
      easybarLog.info(
        """
        screen frame=\(NSStringFromRect(screen.frame))
        visible=\(NSStringFromRect(screen.visibleFrame))
        """)
    } else {
      easybarLog.warn("no screen available during startup logging")
    }
  }

  /// Logs relevant process environment overrides.
  private func logEnvironmentDetails() {
    let env = ProcessInfo.processInfo.environment
    let configOverride = env["\(SharedEnvironmentKeys.configPath)"] ?? ""
    let logLevel = env["\(SharedEnvironmentKeys.loggingLevel)"] ?? ""

    easybarLog.info(
      "environment \(SharedEnvironmentKeys.configPath)=\(configOverride.isEmpty ? "<unset>" : configOverride)"
    )
    easybarLog.info(
      "environment \(SharedEnvironmentKeys.loggingLevel)=\(logLevel.isEmpty ? "<unset>" : logLevel)"
    )
  }

  /// Logs the configured environment overrides passed to the Lua runtime.
  private func logConfiguredEnvironment() {
    let environment = Config.shared.appSection.environment

    guard !environment.isEmpty else {
      easybarLog.info("app env=<empty>")
      return
    }

    for key in environment.keys.sorted() {
      let value = environment[key] ?? ""
      easybarLog.info("app env \(key)=\(value)")
    }
  }

  /// Logs whether required custom fonts are available at runtime.
  private func validateRequiredFonts() {
    validateFont(named: "Symbols Nerd Font Mono")
  }

  /// Logs one warning when a required font is missing.
  private func validateFont(named fontName: String) {
    if NSFont(name: fontName, size: 12) != nil {
      easybarLog.info("font available name=\(fontName)")
      return
    }

    easybarLog.warn(
      "font missing name=\(fontName); Nerd Font icons may render incorrectly or be clipped")
  }

  /// Installs the bundled Lua editor stub into the configured editor-stub path.
  private func installWidgetEditorStub() {
    guard let bundledStub = Bundle.module.url(forResource: "easybar_api", withExtension: "lua")
    else {
      easybarLog.warn("easybar_api.lua not found in bundle resources")
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
      easybarLog.info("installed widget editor stub path=\(installedStub.path)")
    } catch {
      easybarLog.warn("failed to install widget editor stub: \(error)")
    }
  }

  /// Starts one shared shutdown task when the app is still running.
  private func ensureShutdownTask() -> Task<Void, Never>? {
    if let shutdownTask {
      return shutdownTask
    }

    guard started else { return nil }
    started = false

    easybarLog.info("easybar shutting down")
    signalHandler.stop()

    let shutdownTask = Task {
      await RuntimeCoordinator.shared.stop()
    }

    self.shutdownTask = shutdownTask
    return shutdownTask
  }
}
