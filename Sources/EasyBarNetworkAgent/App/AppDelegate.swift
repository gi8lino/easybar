import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let appController = AppController()

  /// Exit code returned by `EasyBarNetworkAgentMain.main()` after the app loop stops.
  private(set) var exitCode: Int32 = 0

  /// Starts the network agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    guard appController.start() else {
      exitCode = 1
      NSApp.terminate(nil)
      return
    }
  }

  /// Stops the network agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    stop()
  }

  /// Stops the network agent explicitly from `main()` after the app loop returns.
  func stop() {
    appController.stop()
  }
}
