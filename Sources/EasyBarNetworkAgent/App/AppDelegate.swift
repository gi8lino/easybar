import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let appController = AppController()

  /// Starts the network agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    appController.start()
  }

  /// Stops the network agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    appController.stop()
  }
}
