import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    AppController.shared.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    AppController.shared.stop()
  }
}
