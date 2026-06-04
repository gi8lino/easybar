import AppKit
import Darwin
import EasyBarShared
import Foundation

/// Process entry point for EasyBar.
@main
enum EasyBarAppMain {
  /// Starts the AppKit application loop and exits with the delegate's final code.
  @MainActor
  static func main() {
    let logger = ProcessLogger(label: "easybar")

    logger.debug("main entered", .field("pid", getpid()))

    let app = NSApplication.shared
    logger.debug("NSApplication.shared created")

    let delegate = AppDelegate(logger: logger)
    app.delegate = delegate
    logger.debug("AppDelegate installed")

    logger.debug("NSApplication.run starting")
    app.run()
    logger.debug("NSApplication.run ended", .field("exit_code", delegate.exitCode))

    delegate.stop()
    Foundation.exit(delegate.exitCode)
  }
}
