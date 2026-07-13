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

  let logger: ProcessLogger

  private let stateLock = LockedState(())
  fileprivate(set) var processIdentifierValue: Int32?
  fileprivate(set) var processGroupIdentifier: Int32?
  fileprivate(set) var isShuttingDown = false
  var terminationTask: Task<Void, Never>?
  var forcedKillTask: Task<Void, Never>?
  private var shutdownWaiters: [CheckedContinuation<Void, Never>] = []

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
    resources: LaunchResources
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
    guard let snapshot = shutdownSnapshot() else {
      logger.debug("lua runtime shutdown skipped because no process is running")
      return
    }

    if snapshot.isShuttingDown {
      logger.debug(
        "lua runtime shutdown already in progress",
        .field("pid", snapshot.processIdentifier)
      )
      await waitForShutdownCompletion()
      return
    }

    withLock {
      isShuttingDown = true
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

  /// Clears the currently tracked Lua process state.
  func clearTrackedProcessState() {
    let clearedState = withLock {
      () -> (Task<Void, Never>?, Task<Void, Never>?, [CheckedContinuation<Void, Never>]) in
      let source = terminationTask
      let workItem = forcedKillTask
      let waiters = shutdownWaiters

      terminationTask = nil
      forcedKillTask = nil
      processIdentifierValue = nil
      processGroupIdentifier = nil
      isShuttingDown = false
      shutdownWaiters.removeAll()

      return (source, workItem, waiters)
    }

    clearedState.0?.cancel()
    clearedState.1?.cancel()
    resumeShutdownWaiters(clearedState.2)
  }

  /// Clears the tracked Lua process only when it matches the given pid.
  func clearTrackedProcessIfMatching(pid: Int32) {
    guard withLock({ processIdentifierValue == pid }) else { return }

    clearTrackedProcessState()
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

  /// Returns the current shutdown-relevant process snapshot.
  private func shutdownSnapshot() -> (
    processIdentifier: Int32,
    processGroupIdentifier: Int32?,
    isShuttingDown: Bool
  )? {
    withLock {
      guard let processIdentifierValue else { return nil }

      return (processIdentifierValue, processGroupIdentifier, isShuttingDown)
    }
  }

  /// Runs one closure while holding the process-state lock.
  func withLock<T>(_ body: () -> T) -> T {
    stateLock.withLock { _ in body() }
  }
}
