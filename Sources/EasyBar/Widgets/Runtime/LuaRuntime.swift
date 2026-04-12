import Foundation

/// Facade for the Lua runtime used by scripted widgets.
///
/// Process lifecycle, transport, and log routing are split into dedicated helpers.
final class LuaRuntime {

  static let shared = LuaRuntime()

  private let processController = LuaProcessController()
  private let transport = LuaTransport()

  private init() {}

  /// Returns the running Lua process identifier when available.
  var processIdentifier: Int32? {
    processController.processIdentifier
  }

  /// Starts the Lua runtime if it is not already running.
  func start() {
    guard let result = processController.start() else { return }
    MetricsCoordinator.shared.recordLuaRuntimeStarted(pid: result.process.processIdentifier)
    attachAndStartTransport(result)
  }

  /// Stops the Lua runtime and clears all pipe handlers.
  func shutdown() {
    MetricsCoordinator.shared.recordLuaRuntimeStopped()
    transport.shutdown()
    processController.shutdown()
  }

  /// Sends one encoded event line to the Lua runtime stdin.
  func send(_ string: String) {
    transport.send(string)
  }

  /// Attaches the process pipes to the transport and starts reading them.
  private func attachAndStartTransport(
    _ result: (process: Process, input: Pipe, output: Pipe, error: Pipe)
  ) {
    transport.attach(
      input: result.input,
      output: result.output,
      error: result.error
    )
    transport.startReading()
  }
}
