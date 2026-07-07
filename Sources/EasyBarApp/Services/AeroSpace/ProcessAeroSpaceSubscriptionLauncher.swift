import Foundation

/// Default subscription launcher backed by Foundation `Process`.
final class ProcessAeroSpaceSubscriptionLauncher: AeroSpaceSubscriptionLaunching, @unchecked Sendable {
  /// Runner used to locate and configure the AeroSpace process.
  private let commandRunner: AeroSpaceCommandRunner

  /// Creates one process-backed launcher.
  init(commandRunner: AeroSpaceCommandRunner) {
    self.commandRunner = commandRunner
  }

  /// Returns whether the AeroSpace subscribe command can currently be launched.
  func canLaunchSubscription(arguments: [String]) -> Bool {
    commandRunner.makeProcess(arguments: arguments) != nil
  }

  /// Creates one process-backed subscription session.
  func makeSubscription(arguments: [String]) -> AeroSpaceSubscriptionSession? {
    guard let process = commandRunner.makeProcess(arguments: arguments) else { return nil }
    return ProcessAeroSpaceSubscriptionSession(process: process)
  }
}

/// Process-backed AeroSpace subscription session.
private final class ProcessAeroSpaceSubscriptionSession: AeroSpaceSubscriptionSession, @unchecked Sendable {
  /// Process running `aerospace subscribe`.
  private let process: Process
  /// Lock guarding one-time resource release.
  private let releaseLock = NSLock()
  /// Whether callbacks and file handles were already released.
  private var released = false
  /// Read handle for stdout.
  private var outputHandle: FileHandle?
  /// Read handle for stderr.
  private var errorHandle: FileHandle?

  /// Process-style termination status from the finished subscription.
  var terminationStatus: Int32 {
    process.terminationStatus
  }

  /// Creates one process-backed subscription session.
  init(process: Process) {
    self.process = process
  }

  /// Starts the process and wires stdout/stderr callbacks.
  func start(
    onOutputData: @escaping @Sendable (Data) -> Void,
    onErrorData: @escaping @Sendable (Data) -> Void,
    onTermination: @escaping @Sendable (AeroSpaceSubscriptionSession) -> Void
  ) throws {
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let outputHandle = outputPipe.fileHandleForReading
    let errorHandle = errorPipe.fileHandleForReading

    self.outputHandle = outputHandle
    self.errorHandle = errorHandle
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    outputHandle.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      onOutputData(data)
    }
    errorHandle.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      onErrorData(data)
    }
    process.terminationHandler = { [weak self] _ in
      guard let self else { return }
      onTermination(self)
    }

    do {
      try process.run()
    } catch {
      invalidate()
      throw error
    }
  }

  /// Stops the process and releases callbacks/file handles immediately.
  func stop() {
    outputHandle?.readabilityHandler = nil
    errorHandle?.readabilityHandler = nil
    process.terminationHandler = nil

    if process.isRunning {
      process.terminate()
    }

    invalidate()
  }

  /// Releases callbacks and file handles.
  func invalidate() {
    guard markReleased() else { return }

    process.terminationHandler = nil
    outputHandle?.readabilityHandler = nil
    errorHandle?.readabilityHandler = nil

    try? outputHandle?.close()
    try? errorHandle?.close()
    outputHandle = nil
    errorHandle = nil
  }

  /// Marks this session as released once.
  private func markReleased() -> Bool {
    releaseLock.lock()
    defer { releaseLock.unlock() }

    guard !released else { return false }
    released = true
    return true
  }
}
