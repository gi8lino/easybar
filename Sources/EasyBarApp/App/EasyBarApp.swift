import AppKit
import Foundation

/// Process entry point for EasyBar.
@main
enum EasyBarAppMain {
  /// Runs validation-only mode or starts the AppKit application loop.
  @MainActor
  static func main() {
    if let validationExitCode = AppValidationMode.exitCodeIfRequested() {
      Foundation.exit(validationExitCode)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()

    app.delegate = delegate
    app.run()

    delegate.stop()
    Foundation.exit(delegate.exitCode)
  }
}
