import AppKit
import EasyBarShared
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {

  private var barWindowController: BarWindowController?
  private let aeroSpaceService = AeroSpaceService.shared
  private let socketServer = SocketServer()
  private let configFileWatcher = ConfigFileWatcher.shared

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    configureLogging()

    logStartup()
    installWidgetEditorStub()
    setupBarWindowController()
    startRuntimeServices()
    startSocketServer()
  }

  func applicationWillTerminate(_ notification: Notification) {
    Logger.info("easybar shutting down")

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
    reloadRuntimeServices()
    aeroSpaceService.triggerRefresh()
  }

  /// Configures file logging from the current app config.
  private func configureLogging() {
    Logger.configureFileLogging(
      enabled: Config.shared.loggingEnabled,
      path: Logger.fileLoggingPath
    )
  }

  /// Creates and presents the main bar window controller.
  private func setupBarWindowController() {
    let controller = BarWindowController()
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

  /// Starts the IPC server used by easybarctl and external triggers.
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

    case .refresh:
      handleForcedRefresh()

    case .reloadConfig:
      reloadConfig()
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

  /// Handles one forced-refresh IPC trigger.
  private func handleForcedRefresh() {
    aeroSpaceService.triggerRefresh()
    EventBus.shared.emit(.forced)
  }

  /// Logs one startup snapshot so service-vs-local differences are visible.
  private func logStartup() {
    logBundleDetails()
    logConfigDetails()
    logScreenDetails()
    logEnvironmentDetails()
  }

  /// Logs app bundle and process identity details.
  private func logBundleDetails() {
    let bundle = Bundle.main
    let info = bundle.infoDictionary ?? [:]
    let bundleID = bundle.bundleIdentifier ?? "unknown"
    let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
    let build = info["CFBundleVersion"] as? String ?? "unknown"
    let executable = bundle.executableURL?.path ?? "unknown"
    let bundlePath = bundle.bundleURL.path
    let processID = ProcessInfo.processInfo.processIdentifier

    Logger.info(
      "easybar startup version=\(version) build=\(build) bundle_id=\(bundleID) pid=\(processID)")
    Logger.info("app bundle_path=\(bundlePath)")
    Logger.info("app executable=\(executable)")
  }

  /// Logs config-derived startup details.
  private func logConfigDetails() {
    Logger.info("config path=\(Config.shared.configPath)")
    Logger.info("widgets path=\(Config.shared.widgetsPath)")
    Logger.info("lua path=\(Config.shared.luaPath)")
    Logger.info("watch config=\(Config.shared.watchConfigFile)")
    Logger.info(
      "logging enabled=\(Config.shared.loggingEnabled) debug=\(Config.shared.loggingDebugEnabled) directory=\(Config.shared.loggingDirectory) path=\(Logger.fileLoggingPath)"
    )
    Logger.info(
      "calendar agent enabled=\(Config.shared.calendarAgentEnabled) socket=\(Config.shared.calendarAgentSocketPath)"
    )
    Logger.info(
      "network agent enabled=\(Config.shared.networkAgentEnabled) socket=\(Config.shared.networkAgentSocketPath) refresh_interval_seconds=\(Config.shared.networkAgentRefreshIntervalSeconds)"
    )
    Logger.info(
      "calendar builtin enabled=\(Config.shared.builtinCalendar.enabled) layout=\(Config.shared.builtinCalendar.layout.rawValue) position=\(Config.shared.builtinCalendar.position.rawValue)"
    )
    Logger.info(
      "wifi builtin enabled=\(Config.shared.builtinWiFi.enabled) position=\(Config.shared.builtinWiFi.position.rawValue)"
    )
    Logger.info(
      "bar height=\(Config.shared.barHeight) padding_x=\(Config.shared.barPaddingX) extend_behind_notch=\(Config.shared.barExtendBehindNotch)"
    )
  }

  /// Logs screen geometry visible at startup.
  private func logScreenDetails() {
    if let screen = NSScreen.main ?? NSScreen.screens.first {
      Logger.info(
        "screen frame=\(NSStringFromRect(screen.frame)) visible=\(NSStringFromRect(screen.visibleFrame))"
      )
    } else {
      Logger.warn("no screen available during startup logging")
    }
  }

  /// Logs relevant environment overrides.
  private func logEnvironmentDetails() {
    let env = ProcessInfo.processInfo.environment
    let configOverride = env["EASYBAR_CONFIG_PATH"] ?? ""
    let debug = env["EASYBAR_DEBUG"] ?? ""

    Logger.info(
      "environment EASYBAR_CONFIG_PATH=\(configOverride.isEmpty ? "<unset>" : configOverride)")
    Logger.info("environment EASYBAR_DEBUG=\(debug.isEmpty ? "<unset>" : debug)")
  }

  /// Installs the bundled Lua editor stub into the active widget directory.
  private func installWidgetEditorStub() {
    guard let bundledStub = Bundle.module.url(forResource: "easybar_api", withExtension: "lua") else {
      Logger.warn("easybar_api.lua not found in bundle resources")
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
      Logger.info("installed widget editor stub path=\(installedStub.path)")
    } catch {
      Logger.warn("failed to install widget editor stub: \(error)")
    }
  }
}
