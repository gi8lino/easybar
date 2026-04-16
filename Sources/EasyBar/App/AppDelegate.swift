import AppKit
import EasyBarShared
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var barWindowController: BarWindowController?
  private let configErrorWindowController = ConfigErrorWindowController()
  private let instanceGuard = SingleInstanceGuard()

  func applicationDidFinishLaunching(_ notification: Notification) {
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

    RuntimeUIBridge.shared.appDelegate = self

    NSApp.setActivationPolicy(.accessory)

    logStartup()
    validateRequiredFonts()
    installWidgetEditorStub()
    setupBarWindowController()
    updateConfigErrorWindow()

    Task {
      await RuntimeCoordinator.shared.start()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    easybarLog.info("easybar shutting down")

    Task {
      await RuntimeCoordinator.shared.stop()
    }
  }

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    NSApp.terminate(nil)
    fatalError("Application should have terminated")
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

  /// Called by the runtime bridge to reload the bar layout.
  func reloadBarLayoutFromRuntime() {
    installWidgetEditorStub()
    barWindowController?.reloadLayout()
  }

  /// Called by the runtime bridge to keep the config error window in sync.
  func updateConfigErrorWindowFromRuntime() {
    updateConfigErrorWindow()
  }

  /// Keeps the config error window in sync with the last known load result.
  private func updateConfigErrorWindow() {
    guard let failureState = Config.shared.loadFailureState else {
      configErrorWindowController.close()
      return
    }

    configErrorWindowController.present(
      failureState: failureState,
      configPath: Config.shared.configPath
    )
  }

  /// Logs one startup snapshot so service-vs-local differences are visible.
  private func logStartup() {
    logProcessStartup(
      snapshot: makeProcessStartupSnapshot(
        processName: "easybar",
        configPath: Config.shared.configPath,
        socketSummary: "socket path=\(SharedRuntimeConfig.current.easyBarSocketPath)",
        loggingSummary:
          "logging enabled=\(easybarLog.fileLoggingEnabled) level=\(easybarLog.minimumLevel.rawValue) path=\(easybarLog.fileLoggingPath)"
      ),
      write: easybarLog.info
    )

    logConfigDetails()
    logScreenDetails()
    logEnvironmentDetails()
  }

  /// Logs config-derived startup details.
  private func logConfigDetails() {
    easybarLog.info("widgets path=\(Config.shared.widgetsPath)")
    easybarLog.info("lua path=\(Config.shared.luaPath)")
    easybarLog.info("watch config=\(Config.shared.watchConfigFile)")
    easybarLog.info(
      "calendar agent enabled=\(Config.shared.calendarAgentEnabled) socket=\(Config.shared.calendarAgentSocketPath)"
    )
    easybarLog.info(
      "network agent enabled=\(Config.shared.networkAgentEnabled) socket=\(Config.shared.networkAgentSocketPath) refresh_interval_seconds=\(Config.shared.networkAgentRefreshIntervalSeconds)"
    )
    easybarLog.info(
      "calendar builtin enabled=\(Config.shared.builtinCalendar.enabled) popup_mode=\(Config.shared.builtinCalendar.popupMode.rawValue) anchor_layout=\(Config.shared.builtinCalendar.anchor.layout.rawValue) position=\(Config.shared.builtinCalendar.position.rawValue)"
    )
    easybarLog.info(
      "wifi builtin enabled=\(Config.shared.builtinWiFi.enabled) position=\(Config.shared.builtinWiFi.position.rawValue)"
    )
    easybarLog.info(
      "bar height=\(Config.shared.barHeight) padding_x=\(Config.shared.barPaddingX) extend_behind_notch=\(Config.shared.barExtendBehindNotch)"
    )
  }

  /// Logs screen geometry visible at startup.
  private func logScreenDetails() {
    if let screen = NSScreen.main ?? NSScreen.screens.first {
      easybarLog.info(
        "screen frame=\(NSStringFromRect(screen.frame)) visible=\(NSStringFromRect(screen.visibleFrame))"
      )
    } else {
      easybarLog.warn("no screen available during startup logging")
    }
  }

  /// Logs relevant environment overrides.
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
      "font missing name=\(fontName); Nerd Font icons may render incorrectly or be clipped"
    )
  }

  /// Installs the bundled Lua editor stub into the active widget directory.
  private func installWidgetEditorStub() {
    guard let bundledStub = Bundle.module.url(forResource: "easybar_api", withExtension: "lua")
    else {
      easybarLog.warn("easybar_api.lua not found in bundle resources")
      return
    }

    let supportDirectory = defaultSupportDirectoryPath()
    let installedStub = defaultWidgetEditorStubPath()
    let fileManager = FileManager.default

    do {
      try fileManager.createDirectory(
        at: supportDirectory,
        withIntermediateDirectories: true
      )

      let bundledData = try Data(contentsOf: bundledStub)
      let existingData = try? Data(contentsOf: installedStub)

      guard bundledData != existingData else {
        return
      }

      try bundledData.write(to: installedStub, options: .atomic)
      easybarLog.info("installed widget editor stub path=\(installedStub.path)")
    } catch {
      easybarLog.warn("failed to install widget editor stub: \(error)")
    }
  }
}
