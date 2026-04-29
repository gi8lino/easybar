import EasyBarShared
import Foundation

/// Actor-owned facade for the Lua runtime used by scripted widgets.
actor LuaRuntime {
  private static var sharedInstance: LuaRuntime?

  /// Returns the configured shared Lua runtime.
  static var shared: LuaRuntime {
    guard let sharedInstance else {
      fatalError("LuaRuntime.bootstrap(logger:) must be called before LuaRuntime.shared")
    }

    return sharedInstance
  }

  /// Configures the shared Lua runtime.
  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = LuaRuntime(logger: logger)
  }

  private let logger: ProcessLogger
  private let processController: LuaProcessController
  private let transport: LuaTransport

  private var stdoutHandler: (@Sendable (String) -> Void)?

  /// Creates one Lua runtime.
  init(logger: ProcessLogger) {
    self.logger = logger
    self.processController = LuaProcessController(logger: logger)
    self.transport = LuaTransport(logger: logger)
  }

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

    MetricsCoordinator.shared.recordLuaRuntimeStarted(pid: result.processIdentifier)
    logger.debug("lua runtime facade started pid=\(result.processIdentifier)")
  }

  /// Stops the Lua runtime and clears all pipe handlers.
  func shutdown() async {
    MetricsCoordinator.shared.recordLuaRuntimeStopped()
    transport.shutdown()
    await processController.shutdownAndWait()
    logger.debug("lua runtime facade shutdown completed")
  }

  /// Sends one encoded event line to the Lua runtime stdin.
  func send(_ string: String) {
    transport.send(string)
  }
}
