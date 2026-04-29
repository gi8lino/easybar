import AppKit
import EasyBarShared
import Foundation

/// Bridges terminal/process signals into normal AppKit termination.
@MainActor
final class AppSignalHandler {
  private let logger: ProcessLogger
  private let requestTermination: () -> Void

  private var sigintSource: DispatchSourceSignal?
  private var sigtermSource: DispatchSourceSignal?
  private var started = false

  /// Creates one signal handler.
  init(
    logger: ProcessLogger,
    requestTermination: @escaping () -> Void
  ) {
    self.logger = logger
    self.requestTermination = requestTermination
  }

  /// Starts listening for termination signals.
  func start() {
    guard !started else { return }
    started = true

    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigintSource.setEventHandler { [weak self] in
      guard let self else { return }

      self.logger.info("received SIGINT")
      self.requestTermination()
    }
    sigintSource.resume()
    self.sigintSource = sigintSource

    let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    sigtermSource.setEventHandler { [weak self] in
      guard let self else { return }

      self.logger.info("received SIGTERM")
      self.requestTermination()
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
