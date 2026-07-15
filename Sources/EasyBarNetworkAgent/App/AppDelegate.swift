import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private lazy var appController = AppController { [weak self] in
    self?.exitCode = 75
    NSApp.terminate(nil)
  }

  /// Exit code returned by `EasyBarNetworkAgentMain.main()` after the app loop stops.
  private(set) var exitCode: Int32 = 0

  /// Starts the network agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    switch appController.start() {
    case .running:
      return
    case .disabled:
      exitCode = 0
    case .failed:
      exitCode = 1
    }

    NSApp.terminate(nil)
  }

  /// Stops the network agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    stop()
  }

  /// Stops the network agent explicitly from `main()` after the app loop returns.
  func stop() {
    appController.stop()
  }
}
