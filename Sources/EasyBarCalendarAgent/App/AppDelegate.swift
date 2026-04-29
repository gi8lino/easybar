import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let appController = AppController()

  /// Starts the calendar agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    appController.start()
  }

  /// Stops the calendar agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    appController.stop()
  }
}
