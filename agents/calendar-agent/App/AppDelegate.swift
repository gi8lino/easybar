import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let controller = AppController()

  /// Starts the calendar agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    controller.start()
  }

  /// Stops the calendar agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    controller.stop()
  }
}
