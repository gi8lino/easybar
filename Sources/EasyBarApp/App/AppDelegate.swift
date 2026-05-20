import AppKit
import EasyBarShared
import Foundation

/// AppKit delegate that forwards lifecycle events into `AppController`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  /// Process logger used by the app shell.
  private let logger = ProcessLogger(label: "easybar")
  /// Main app controller created after logger setup.
  private lazy var appController = AppController(logger: logger.child("app"))

  /// Starts EasyBar after AppKit finishes launching.
  func applicationDidFinishLaunching(_ notification: Notification) {
    appController.start()
  }

  /// Requests graceful shutdown before allowing AppKit termination.
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if appController.shouldTerminateImmediately {
      return .terminateNow
    }

    appController.requestTermination()
    return .terminateCancel
  }

  /// Stops EasyBar when AppKit is terminating.
  func applicationWillTerminate(_ notification: Notification) {
    appController.stop()
  }
}
