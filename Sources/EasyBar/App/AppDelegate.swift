import AppKit
import EasyBarShared
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var barWindowController: BarWindowController?
  private let aeroSpaceService = AeroSpaceService.shared
  private let socketServer = SocketServer()
  private let configFileWatcher = ConfigFileWatcher.shared
  private let instanceGuard = SingleInstanceGuard()

  func applicationDidFinishLaunching(_ notification: Notification) {
    let lockPath = defaultSingleInstanceLockPath(
      processName: "easybar",
      directory: Config.shared.lockDirectory
    )

    switch instanceGuard.acquireLock(at: lockPath) {
    case .acquired:
      break

    case .alreadyRunning:
      easybarLog.warn("easybar already running lock_path=\(lockPath)")
      NSApp.terminate(nil)
      return

    case .failed(let reason):
      easybarLog.error(
        "easybar failed to acquire instance lock lock_path=\(lockPath) reason=\(reason)"
      )
      NSApp.terminate(nil)
      return
    }

    NSApp.setActivationPolicy(.accessory)
    configureLogging()

    logStartup()
    validateRequiredFonts()
    installWidgetEditorStub()
    setupBarWindowController()
    startRuntimeServices()
    startSocketServer()
  }

  func applicationWillTerminate(_ notification: Notification) {
    easybarLog.info("easybar shutting down")

    socketServer.stop()
    configFileWatcher.stop()
    NativeWidgetRegistry.shared.stop()
    WidgetRunner.shared.shutdown()
  }

  /// Reloads config and reapplies all dependent runtime state.
  private func reloadConfig() {
    Config.shared.reload()
    configureLogging()
    installWidgetEditorStub()
    barWindowController?.reloadLayout()
    reloadRuntimeServices()
    configFileWatcher.restart()
    aeroSpaceService.triggerRefresh()
  }

  /// Restarts only the Lua runtime without reloading config.
  private func restartLuaRuntime() {
    WidgetRunner.shared.reload()
    aeroSpaceService.triggerRefresh()
  }

  /// Refreshes the current runtime state without reloading config.
  ///
  /// This keeps the current config, refreshes app-coordinated state,
  /// refreshes agent-backed widget data through emitted events, and
  /// notifies Lua widgets with the manual refresh event.
  private func refreshRuntime() {
    aeroSpaceService.triggerRefresh()
    EventBus.shared.emit(.manualRefresh)
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
    controller.onRefresh = { [weak self] in
      self?.refreshRuntime()
    }
    controller.onReloadConfig = { [weak self] in
      self?.reloadConfig()
    }
    controller.onRestartLuaRuntime = { [weak self] in
      self?.restartLuaRuntime()
    }
    controller.present()
    barWindowController = controller
  }

  /// Starts the shared runtime services used by the app.
  private func startRuntimeServices() {
    aeroSpaceService.start()
    WidgetRunner.shared.start()
    NativeWidgetRegistry.shared.start()
    configFileWatcher.start()
  }

  /// Reloads the Lua and native widget runtime services.
  private func reloadRuntimeServices() {
    WidgetRunner.shared.reload()
    NativeWidgetRegistry.shared.reload()
  }

  /// Starts the IPC server used by easybar and external triggers.
  private func startSocketServer() {
    socketServer.start { [weak self] command in
      self?.handleSocketCommand(command)
    }
  }

  /// Handles one incoming IPC command from the socket server.
  private func handleSocketCommand(_ command: IPC.Command) {
    switch command {
    case .workspaceChanged:
      handleWorkspaceChanged()

    case .focusChanged:
      handleFocusChanged()

    case .spaceModeChanged:
      handleSpaceModeChanged()

    case .manualRefresh:
      handleManualRefresh()

    case .reloadConfig:
      reloadConfig()

    case .restartLuaRuntime:
      restartLuaRuntime()
    }
  }

  /// Handles one workspace-changed IPC trigger.
  private func handleWorkspaceChanged() {
    aeroSpaceService.triggerRefresh()
    EventBus.shared.emit(.workspaceChange)
  }

  /// Handles one focus-changed IPC trigger.
  private func handleFocusChanged() {
    aeroSpaceService.triggerRefresh()
    EventBus.shared.emit(.focusChange)
  }

  /// Handles one space-mode-changed IPC trigger.
  private func handleSpaceModeChanged() {
    aeroSpaceService.triggerRefresh()
    EventBus.shared.emit(.spaceModeChange)
  }

  /// Handles one manual-refresh IPC trigger.
  private func handleManualRefresh() {
    refreshRuntime()
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
    let logLevel = env["\(SharedEnvironmentKeys.logLevel)"] ?? ""

    easybarLog.info(
      "environment \(SharedEnvironmentKeys.configPath)=\(configOverride.isEmpty ? "<unset>" : configOverride)"
    )
    easybarLog.info(
      "environment \(SharedEnvironmentKeys.logLevel)=\(logLevel.isEmpty ? "<unset>" : logLevel)"
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
