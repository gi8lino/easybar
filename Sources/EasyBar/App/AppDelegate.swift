import AppKit
import EasyBarShared
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = ProcessLogger(label: "easybar")
  private lazy var appController = AppController(logger: logger.child("app"))

  /// Handles application did finish launching.
  func applicationDidFinishLaunching(_ notification: Notification) {
    appController.start()
  }

  /// Handles application should terminate.
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if appController.shouldTerminateImmediately {
      return .terminateNow
    }

    appController.requestTermination()
    return .terminateCancel
  }

  /// Handles application will terminate.
  func applicationWillTerminate(_ notification: Notification) {
    appController.stop()
  }
}
