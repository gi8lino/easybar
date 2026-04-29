import Darwin
import EasyBarShared
import Foundation

/// Owns Lua process lifecycle.
final class LuaProcessController {
  struct LaunchContext {
    let runtimePath: String
    let luaPath: String
    let widgetsPath: String
    let environment: [String: String]
  }

  struct LaunchPipes {
    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
  }

  let logger: ProcessLogger

  private let stateLock = NSLock()
  fileprivate(set) var processIdentifierValue: Int32?
  fileprivate(set) var processGroupIdentifier: Int32?
  fileprivate(set) var isShuttingDown = false
  var terminationSource: DispatchSourceProcess?
  var forcedKillWorkItem: DispatchWorkItem?
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

  /// Starts the Lua runtime process and returns its pipes.
  func start() -> (processIdentifier: Int32, input: Pipe, output: Pipe, error: Pipe)? {
    if withLock({ isShuttingDown }) {
      logger.debug("lua runtime start skipped because shutdown is in progress")
      return nil
    }

    guard withLock({ processIdentifierValue == nil }) else {
      logger.debug("lua runtime already started")
      return nil
    }

    guard let context = launchContext() else { return nil }

    logLaunch(context: context)

    let pipes = LaunchPipes()

    do {
      let pid = try spawnProcess(context: context, pipes: pipes)

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

      return (pid, pipes.input, pipes.output, pipes.error)
    } catch {
      closeLaunchPipesAfterFailedSpawn(pipes)
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
      () -> (DispatchSourceProcess?, DispatchWorkItem?, [CheckedContinuation<Void, Never>]) in
      let source = terminationSource
      let workItem = forcedKillWorkItem
      let waiters = shutdownWaiters

      terminationSource = nil
      forcedKillWorkItem = nil
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
    waiters.forEach { $0.resume() }
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
    stateLock.lock()
    defer { stateLock.unlock() }

    return body()
  }
}
