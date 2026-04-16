import Darwin
import Foundation

/// Owns Lua process lifecycle.
final class LuaProcessController {

  struct LaunchContext {
    let runtimePath: String
    let luaPath: String
    let widgetsPath: String
  }

  struct LaunchPipes {
    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
  }

  fileprivate(set) var processIdentifierValue: Int32?
  fileprivate(set) var processGroupIdentifier: Int32?
  fileprivate(set) var isShuttingDown = false
  var terminationSource: DispatchSourceProcess?
  private var shutdownWaiters: [CheckedContinuation<Void, Never>] = []

  /// Returns the running Lua process identifier when available.
  var processIdentifier: Int32? {
    processIdentifierValue
  }

  /// Starts the Lua runtime process and returns its pipes.
  func start() -> (processIdentifier: Int32, input: Pipe, output: Pipe, error: Pipe)? {
    if isShuttingDown {
      easybarLog.debug("lua runtime start skipped because shutdown is in progress")
      return nil
    }

    guard processIdentifierValue == nil else {
      easybarLog.debug("lua runtime already started")
      return nil
    }

    guard let context = launchContext() else { return nil }

    logLaunch(context: context)

    let pipes = LaunchPipes()

    do {
      let pid = try spawnProcess(context: context, pipes: pipes)

      easyBarLuaForcedKillWorkItem?.cancel()
      easyBarLuaForcedKillWorkItem = nil

      processIdentifierValue = pid
      processGroupIdentifier = pid
      isShuttingDown = false

      installTerminationSource(for: pid)

      easybarLog.debug("lua runtime started pid=\(pid) pgid=\(pid)")

      return (pid, pipes.input, pipes.output, pipes.error)
    } catch {
      closeLaunchPipesAfterFailedSpawn(pipes)
      easybarLog.error("failed to start lua runtime: \(error)")
      return nil
    }
  }

  /// Stops the Lua runtime process and waits until the child has fully exited.
  func shutdownAndWait() async {
    guard let processIdentifierValue else {
      easybarLog.debug("lua runtime shutdown skipped because no process is running")
      return
    }

    if isShuttingDown {
      easybarLog.debug("lua runtime shutdown already in progress pid=\(processIdentifierValue)")
      await waitForShutdownCompletion()
      return
    }

    isShuttingDown = true

    if let processGroupIdentifier {
      easybarLog.debug(
        "shutting down lua runtime pid=\(processIdentifierValue) pgid=\(processGroupIdentifier)"
      )
    } else {
      easybarLog.debug("shutting down lua runtime pid=\(processIdentifierValue)")
    }

    easyBarTerminateLuaProcess(
      processIdentifier: processIdentifierValue,
      processGroupIdentifier: processGroupIdentifier
    )

    await waitForShutdownCompletion()
  }

  /// Clears the currently tracked Lua process state.
  func clearTrackedProcessState() {
    terminationSource?.cancel()
    terminationSource = nil
    processIdentifierValue = nil
    processGroupIdentifier = nil
    isShuttingDown = false
    resumeShutdownWaiters()
  }

  /// Clears the tracked Lua process only when it matches the given pid.
  func clearTrackedProcessIfMatching(pid: Int32) {
    guard processIdentifierValue == pid else { return }
    clearTrackedProcessState()
  }

  /// Suspends until the current shutdown sequence has completed.
  private func waitForShutdownCompletion() async {
    if processIdentifierValue == nil {
      return
    }

    await withCheckedContinuation { continuation in
      shutdownWaiters.append(continuation)
    }
  }

  /// Resumes all pending shutdown waiters.
  private func resumeShutdownWaiters() {
    let waiters = shutdownWaiters
    shutdownWaiters.removeAll()

    waiters.forEach { $0.resume() }
  }
}
