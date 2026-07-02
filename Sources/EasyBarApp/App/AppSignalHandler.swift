import AppKit
import Darwin
import EasyBarShared
import Foundation

/// Bridges terminal/process signals into normal AppKit termination.
@MainActor
final class AppSignalHandler {
  /// Logger used for signal diagnostics.
  private let logger: ProcessLogger
  /// Callback invoked when a termination signal is received.
  private let requestTermination: () -> Void

  /// Task waiting for SIGINT/SIGTERM via `sigwait`.
  private var signalTask: Task<Void, Never>?
  /// Whether signal handling is currently active.
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

    var signalSet = sigset_t()
    sigemptyset(&signalSet)
    sigaddset(&signalSet, SIGINT)
    sigaddset(&signalSet, SIGTERM)
    pthread_sigmask(SIG_BLOCK, &signalSet, nil)
    let signalSetSnapshot = signalSet

    signalTask = DetachedTask.run { [weak self] in
      var waitSet = signalSetSnapshot

      while !Task.isCancelled {
        var receivedSignal: Int32 = 0
        let result = sigwait(&waitSet, &receivedSignal)
        guard result == 0, !Task.isCancelled else { continue }
        let signal = receivedSignal

        await MainActor.run { [weak self] in
          guard let self, self.started else { return }

          switch signal {
          case SIGINT:
            self.logger.info("received SIGINT")
          case SIGTERM:
            self.logger.info("received SIGTERM")
          default:
            self.logger.info("received termination signal", .field("signal", signal))
          }

          self.requestTermination()
        }
      }
    }
  }

  /// Stops listening for termination signals.
  func stop() {
    guard started else { return }
    started = false

    signalTask?.cancel()
    signalTask = nil
  }
}
