import AppKit
import Foundation

/// Bridges terminal/process signals into normal AppKit termination.
@MainActor
final class AppSignalHandler {
  private var sigintSource: DispatchSourceSignal?
  private var sigtermSource: DispatchSourceSignal?
  private var started = false

  /// Starts listening for termination signals.
  func start() {
    guard !started else { return }
    started = true

    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSource.setEventHandler {
      easybarLog.info("received SIGINT")
      NSApp.terminate(nil)
    }
    sigintSource.resume()
    self.sigintSource = sigintSource

    let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigtermSource.setEventHandler {
      easybarLog.info("received SIGTERM")
      NSApp.terminate(nil)
    }
    sigtermSource.resume()
    self.sigtermSource = sigtermSource
  }

  /// Stops listening for termination signals.
  func stop() {
    guard started else { return }
    started = false

    sigintSource?.cancel()
    sigintSource = nil

    sigtermSource?.cancel()
    sigtermSource = nil
  }
}
