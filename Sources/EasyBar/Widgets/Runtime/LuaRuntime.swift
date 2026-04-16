import Foundation

/// Actor-owned facade for the Lua runtime used by scripted widgets.
actor LuaRuntime {
  static let shared = LuaRuntime()

  private let processController = LuaProcessController()
  private let transport = LuaTransport()

  private var stdoutHandler: (@Sendable (String) -> Void)?

  /// Returns the running Lua process identifier when available.
  var processIdentifier: Int32? {
    processController.processIdentifier
  }

  /// Sets the current stdout line handler for the Lua runtime.
  func setStdoutHandler(_ handler: @escaping @Sendable (String) -> Void) {
    stdoutHandler = handler
  }

  /// Starts the Lua runtime if it is not already running.
  func start() {
    guard let result = processController.start() else { return }

    transport.attach(
      input: result.input,
      output: result.output,
      error: result.error,
      stdoutHandler: stdoutHandler ?? { _ in }
    )
    transport.startReading()

    MetricsCoordinator.shared.recordLuaRuntimeStarted(pid: result.process.processIdentifier)
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
}
