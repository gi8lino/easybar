import AppKit
import EasyBarNetworkAgentCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let controller = NetworkAgentController()

  /// Starts the network agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    guard controller.start() else {
      NSApp.terminate(nil)
      return
    }
  }

  /// Stops the network agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    controller.stop()
  }
}
