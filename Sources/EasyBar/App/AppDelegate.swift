import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var barWindowController: BarWindowController?
    private let aeroSpaceService = AeroSpaceService.shared
    private let socketServer = SocketServer()
    private let configFileWatcher = ConfigFileWatcher.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = BarWindowController()
        controller.showWindow(self)
        barWindowController = controller

        aeroSpaceService.start()
        WidgetRunner.shared.start()
        NativeWidgetRegistry.shared.start()
        configFileWatcher.start()

        socketServer.start { [weak self] command in
            switch command {
            case .workspaceChanged:
                self?.aeroSpaceService.triggerRefresh()
                EventBus.shared.emit("workspace_change")

            case .focusChanged:
                self?.aeroSpaceService.triggerRefresh()
                EventBus.shared.emit("focus_change")

            case .refresh:
                self?.aeroSpaceService.triggerRefresh()
                EventBus.shared.emit("forced")

            case .reloadConfig:
                Config.shared.reload()
                WidgetRunner.shared.reload()
                NativeWidgetRegistry.shared.reload()
                self?.configFileWatcher.restart()
                self?.aeroSpaceService.triggerRefresh()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        configFileWatcher.stop()
        NativeWidgetRegistry.shared.stop()
        WidgetRunner.shared.shutdown()
    }
}
