import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let controller = AppController()

  /// Starts the network agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    controller.start()
  }

  /// Stops the network agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    controller.stop()
  }
}
