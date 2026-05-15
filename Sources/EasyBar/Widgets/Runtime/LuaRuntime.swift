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

  private var lineHandler: (@Sendable (String) -> Void)?

  /// Creates one Lua runtime.
  init(logger: ProcessLogger) {
    self.logger = logger
    self.processController = LuaProcessController(logger: logger.child("process"))
    self.transport = LuaTransport(logger: logger.child("transport"))
  }

  /// Returns the running Lua process identifier when available.
  var processIdentifier: Int32? {
    return processController.processIdentifier
  }

  /// Sets the current transport line handler for the Lua runtime.
  func setLineHandler(_ handler: @escaping @Sendable (String) -> Void) {
    lineHandler = handler
    return
  }

  /// Starts the Lua runtime if it is not already running.
  @discardableResult
  func start() -> Bool {
    guard let context = processController.launchContext() else { return false }

    let resources = LuaProcessController.LaunchResources()

    transport.startListening(
      socketPath: context.luaSocketPath,
      error: resources.error,
      lineHandler: lineHandler ?? { _ in }
    )

    guard let result = processController.start(context: context, resources: resources) else {
      transport.shutdown()
      return false
    }

    MetricsCoordinator.shared.recordLuaRuntimeStarted(pid: result.processIdentifier)
    logger.debug(
      "lua runtime facade started",
      .field("pid", result.processIdentifier),
    )
    return true
  }

  /// Stops the Lua runtime and clears all pipe handlers.
  func shutdown() async {
    MetricsCoordinator.shared.recordLuaRuntimeStopped()
    transport.shutdown()
    await processController.shutdownAndWait()
    logger.debug("lua runtime facade shutdown completed")
  }

  /// Sends one encoded event line to the Lua runtime socket transport.
  func send(_ string: String) {
    transport.send(string)
  }
}
