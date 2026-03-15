import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var barWindowController: BarWindowController?
    private let aeroSpaceService = AeroSpaceService()
    private let socketServer = SocketServer()

    func applicationDidFinishLaunching(_ notification: Notification) {

        NSApp.setActivationPolicy(.accessory)

        let controller = BarWindowController(aeroSpaceService: aeroSpaceService)
        controller.showWindow(self)
        barWindowController = controller

        aeroSpaceService.start()
        WidgetRunner.shared.start()

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

            case .reloadConfig:
                Config.shared.reload()
                WidgetRunner.shared.reload()
                self?.aeroSpaceService.triggerRefresh()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        WidgetRunner.shared.shutdown()
    }
}
