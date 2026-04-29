import AppKit
import EasyBarShared
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = ProcessLogger(label: "easybar")
  private lazy var appController = AppController(logger: logger)

  func applicationDidFinishLaunching(_ notification: Notification) {
    appController.start()
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if appController.shouldTerminateImmediately {
      return .terminateNow
    }

    appController.requestTermination()
    return .terminateCancel
  }

  func applicationWillTerminate(_ notification: Notification) {
    appController.stop()
  }
}
