import AppKit
import Darwin
import Foundation

/// Writes one unfiltered bootstrap line to stdout before normal logging is available.
func writeEasyBarBootstrapLog(_ message: String) {
  fputs("[easybar.bootstrap] \(message)\n", stdout)
  fflush(stdout)
}

/// Writes one unfiltered bootstrap line to stderr before normal logging is available.
func writeEasyBarBootstrapErrorLog(_ message: String) {
  fputs("[easybar.bootstrap] \(message)\n", stderr)
  fflush(stderr)
}

/// Process entry point for EasyBar.
@main
enum EasyBarAppMain {
  /// Runs validation-only mode or starts the AppKit application loop.
  @MainActor
  static func main() {
    writeEasyBarBootstrapLog("main entered pid=\(getpid())")

    let app = NSApplication.shared
    writeEasyBarBootstrapLog("NSApplication.shared created")

    let delegate = AppDelegate()
    app.delegate = delegate
    writeEasyBarBootstrapLog("AppDelegate installed")

    writeEasyBarBootstrapLog("NSApplication.run starting")
    app.run()
    writeEasyBarBootstrapLog("NSApplication.run ended exit_code=\(delegate.exitCode)")

    delegate.stop()
    Foundation.exit(delegate.exitCode)
  }
}
