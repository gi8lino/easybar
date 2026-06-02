import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let appController = AppController()

  /// Exit code returned by `EasyBarCalendarAgentMain.main()` after the app loop stops.
  private(set) var exitCode: Int32 = 0

  /// Starts the calendar agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    guard appController.start() else {
      exitCode = 1
      NSApp.terminate(nil)
      return
    }
  }

  /// Stops the calendar agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    stop()
  }

  /// Stops the calendar agent explicitly from `main()` after the app loop returns.
  func stop() {
    appController.stop()
  }
}
