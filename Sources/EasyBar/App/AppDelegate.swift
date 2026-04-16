import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    AppController.shared.start()
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if AppController.shared.shouldTerminateImmediately {
      return .terminateNow
    }

    AppController.shared.requestTermination()
    return .terminateCancel
  }

  func applicationWillTerminate(_ notification: Notification) {
    AppController.shared.stop()
  }
}
