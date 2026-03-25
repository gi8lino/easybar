import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var barWindowController: BarWindowController?
    private let aeroSpaceService = AeroSpaceService.shared
    private let socketServer = SocketServer()
    private let configFileWatcher = ConfigFileWatcher.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Logger.configureFileLogging(
            enabled: Config.shared.loggingEnabled,
            path: Config.shared.loggingPath
        )

        logStartup()

        let controller = BarWindowController()
        controller.present()
        barWindowController = controller

        aeroSpaceService.start()
        WidgetRunner.shared.start()
        NativeWidgetRegistry.shared.start()
        configFileWatcher.start()

        socketServer.start { [weak self] command in
            switch command {
            case .workspaceChanged:
                self?.aeroSpaceService.triggerRefresh()
                EventBus.shared.emit(.workspaceChange)

            case .focusChanged:
                self?.aeroSpaceService.triggerRefresh()
                EventBus.shared.emit(.focusChange)

            case .refresh:
                self?.aeroSpaceService.triggerRefresh()
                EventBus.shared.emit(.forced)

            case .reloadConfig:
                Config.shared.reload()
                Logger.configureFileLogging(
                    enabled: Config.shared.loggingEnabled,
                    path: Config.shared.loggingPath
                )
                self?.barWindowController?.reloadLayout()
                WidgetRunner.shared.reload()
                NativeWidgetRegistry.shared.reload()
                self?.configFileWatcher.restart()
                self?.aeroSpaceService.triggerRefresh()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.info("easybar shutting down")

        configFileWatcher.stop()
        NativeWidgetRegistry.shared.stop()
        WidgetRunner.shared.shutdown()
    }

    /// Logs one startup snapshot so service-vs-local differences are visible.
    private func logStartup() {
        let bundle = Bundle.main
        let info = bundle.infoDictionary ?? [:]

        let bundleID = bundle.bundleIdentifier ?? "unknown"
        let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        let executable = bundle.executableURL?.path ?? "unknown"
        let bundlePath = bundle.bundleURL.path
        let processID = ProcessInfo.processInfo.processIdentifier

        Logger.info("easybar startup version=\(version) build=\(build) bundle_id=\(bundleID) pid=\(processID)")
        Logger.info("app bundle_path=\(bundlePath)")
        Logger.info("app executable=\(executable)")
        Logger.info("config path=\(Config.shared.configPath)")
        Logger.info("widgets path=\(Config.shared.widgetsPath)")
        Logger.info("lua path=\(Config.shared.luaPath)")
        Logger.info("watch config=\(Config.shared.watchConfigFile)")
        Logger.info("calendar agent enabled=\(Config.shared.calendarAgentEnabled) socket=\(Config.shared.calendarAgentSocketPath)")
        Logger.info("network agent enabled=\(Config.shared.networkAgentEnabled) socket=\(Config.shared.networkAgentSocketPath) refresh_interval_seconds=\(Config.shared.networkAgentRefreshIntervalSeconds)")
        Logger.info("calendar builtin enabled=\(Config.shared.builtinCalendar.enabled) layout=\(Config.shared.builtinCalendar.layout.rawValue) position=\(Config.shared.builtinCalendar.position.rawValue)")
        Logger.info("wifi builtin enabled=\(Config.shared.builtinWiFi.enabled) position=\(Config.shared.builtinWiFi.position.rawValue)")
        Logger.info("bar height=\(Config.shared.barHeight) padding_x=\(Config.shared.barPaddingX) extend_behind_notch=\(Config.shared.barExtendBehindNotch)")

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            Logger.info("screen frame=\(NSStringFromRect(screen.frame)) visible=\(NSStringFromRect(screen.visibleFrame))")
        } else {
            Logger.warn("no screen available during startup logging")
        }

        let env = ProcessInfo.processInfo.environment
        let configOverride = env["EASYBAR_CONFIG_PATH"] ?? ""
        let debug = env["EASYBAR_DEBUG"] ?? ""

        Logger.info("environment EASYBAR_CONFIG_PATH=\(configOverride.isEmpty ? "<unset>" : configOverride)")
        Logger.info("environment EASYBAR_DEBUG=\(debug.isEmpty ? "<unset>" : debug)")
    }
}
