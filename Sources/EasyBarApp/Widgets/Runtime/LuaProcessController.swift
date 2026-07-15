import Darwin
import EasyBarShared
import Foundation

/// Owns Lua process lifecycle.
final class LuaProcessController: @unchecked Sendable {
  /// Captures the inputs needed to launch the Lua runtime agent.
  struct LaunchContext {
    let runtimeAgentPath: String
    let runtimePath: String
    let luaPath: String
    let luaSocketPath: String
    let widgetsPath: String
    let defaultCommandTimeoutSeconds: TimeInterval
    let defaultCommandMaxOutputBytes: Int
    let widgetFiles: [String]
    let environment: [String: String]
  }

  /// Captures local resources kept by the host while the runtime agent is running.
  struct LaunchResources {
    let error = Pipe()
  }

  /// Describes one observed Lua child-process termination.
  struct Termination: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
      case exited(code: Int32)
      case signaled(signal: Int32)
      case unknown(status: Int32)
      case reapFailed(errno: Int32)
    }

    let processIdentifier: Int32
    let reason: Reason
    let wasRequested: Bool
  }

  typealias TerminationHandler = @Sendable (Termination) -> Void

  let logger: ProcessLogger

  private let stateLock = LockedState(())
  fileprivate(set) var processIdentifierValue: Int32?
  fileprivate(set) var processGroupIdentifier: Int32?
  fileprivate(set) var isShuttingDown = false
  var terminationTask: Task<Void, Never>?
  var forcedKillTask: Task<Void, Never>?
  private var shutdownWaiters: [CheckedContinuation<Void, Never>] = []
  private var terminationHandler: TerminationHandler?

  /// Creates one Lua process controller.
  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Returns the running Lua process identifier when available.
  var processIdentifier: Int32? {
    withLock {
      processIdentifierValue
    }
  }

  /// Starts the Lua runtime process using the prepared launch context.
  func start(
    context: LaunchContext,
    resources: LaunchResources,
    terminationHandler: @escaping TerminationHandler
  ) -> (processIdentifier: Int32, error: Pipe)? {
    if withLock({ isShuttingDown }) {
      logger.debug("lua runtime start skipped because shutdown is in progress")
      return nil
    }

    guard withLock({ processIdentifierValue == nil }) else {
      logger.debug("lua runtime already started")
      return nil
    }

    logLaunch(context: context)

    do {
      let pid = try spawnProcess(context: context, resources: resources)

      cancelForcedKillWorkItem()
      withLock {
        processIdentifierValue = pid
        processGroupIdentifier = pid
        isShuttingDown = false
        self.terminationHandler = terminationHandler
      }

      installTerminationSource(for: pid)

      logger.debug(
        "lua runtime started",
        .field("pid", pid),
        .field("pgid", pid),
      )

      return (pid, resources.error)
    } catch {
      closeLaunchResourcesAfterFailedSpawn(resources)
      logger.error(
        "failed to start lua runtime",
        .field("error", "\(error)"),
      )
      return nil
    }
  }

  /// Stops the Lua runtime process and waits until the child has fully exited.
  func shutdownAndWait() async {
    guard let snapshot = beginShutdownSnapshot() else {
      logger.debug("lua runtime shutdown skipped because no process is running")
      return
    }

    if snapshot.wasAlreadyShuttingDown {
      logger.debug(
        "lua runtime shutdown already in progress",
        .field("pid", snapshot.processIdentifier)
      )
      await waitForShutdownCompletion()
      return
    }

    if let processGroupIdentifier = snapshot.processGroupIdentifier {
      logger.debug(
        "shutting down lua runtime",
        .field("pid", snapshot.processIdentifier),
        .field("pgid", processGroupIdentifier)
      )
    } else {
      logger.debug(
        "shutting down lua runtime",
        .field("pid", snapshot.processIdentifier),
      )
    }

    terminateProcess(
      processIdentifier: snapshot.processIdentifier,
      processGroupIdentifier: snapshot.processGroupIdentifier
    )

    await waitForShutdownCompletion()
  }

  /// Clears the tracked Lua process and returns its termination delivery state.
  func clearTrackedProcessIfMatching(pid: Int32) -> (
    wasRequested: Bool,
    handler: TerminationHandler?
  )? {
    let clearedState = withLock {
      () -> (
        wasRequested: Bool,
        forcedKillTask: Task<Void, Never>?,
        waiters: [CheckedContinuation<Void, Never>],
        handler: TerminationHandler?
      )? in
      guard processIdentifierValue == pid else { return nil }

      let result = (
        wasRequested: isShuttingDown,
        forcedKillTask: forcedKillTask,
        waiters: shutdownWaiters,
        handler: terminationHandler
      )

      terminationTask = nil
      forcedKillTask = nil
      processIdentifierValue = nil
      processGroupIdentifier = nil
      isShuttingDown = false
      shutdownWaiters.removeAll()
      terminationHandler = nil

      return result
    }

    guard let clearedState else { return nil }

    clearedState.forcedKillTask?.cancel()
    resumeShutdownWaiters(clearedState.waiters)
    return (clearedState.wasRequested, clearedState.handler)
  }

  /// Suspends until the current shutdown sequence has completed.
  private func waitForShutdownCompletion() async {
    if withLock({ processIdentifierValue == nil }) {
      return
    }

    await withCheckedContinuation { continuation in
      let shouldResumeImmediately = withLock { () -> Bool in
        if processIdentifierValue == nil {
          return true
        }

        shutdownWaiters.append(continuation)
        return false
      }

      if shouldResumeImmediately {
        continuation.resume()
      }
    }
  }

  /// Resumes all pending shutdown waiters.
  private func resumeShutdownWaiters(_ waiters: [CheckedContinuation<Void, Never>]) {
    for waiter in waiters {
      waiter.resume()
    }
  }

  /// Atomically begins shutdown and returns the current process snapshot.
  private func beginShutdownSnapshot() -> (
    processIdentifier: Int32,
    processGroupIdentifier: Int32?,
    wasAlreadyShuttingDown: Bool
  )? {
    withLock {
      guard let processIdentifierValue else { return nil }

      let wasAlreadyShuttingDown = isShuttingDown
      isShuttingDown = true
      return (processIdentifierValue, processGroupIdentifier, wasAlreadyShuttingDown)
    }
  }

  /// Runs one closure while holding the process-state lock.
  func withLock<T>(_ body: () -> T) -> T {
    stateLock.withLock { _ in body() }
  }
}
