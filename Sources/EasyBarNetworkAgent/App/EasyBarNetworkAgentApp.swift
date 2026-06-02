import AppKit
import Foundation

/// Process entry point for the network agent.
@main
enum EasyBarNetworkAgentMain {
  /// Starts the AppKit application loop and exits with the delegate's final code.
  @MainActor
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()

    app.delegate = delegate
    app.run()

    delegate.stop()
    Foundation.exit(delegate.exitCode)
  }
}
