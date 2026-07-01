import EasyBarShared
import Foundation

/// Owns the long-lived `aerospace subscribe` process.
final class AeroSpaceSubscriptionController: @unchecked Sendable {
  /// Maximum partial line buffer retained for one process stream.
  private static let maxBufferedBytes = 64 * 1024

  /// One running subscription process and its read handles.
  private struct RunningSubscription {
    let process: Process
    let outputHandle: FileHandle
    let errorHandle: FileHandle
  }

  /// Locked lifecycle state for the subscription process.
  private struct State {
    var running = false
    var generation: UInt64 = 0
    var subscription: RunningSubscription?
    var outputBuffer = Data()
    var errorBuffer = Data()
  }

  /// Stream type currently being decoded.
  private enum StreamKind {
    case output
    case error
  }

  /// Runner used to locate and launch the AeroSpace CLI.
  private let commandRunner: AeroSpaceCommandRunner
  /// Logger used for subscription diagnostics.
  private let logger: ProcessLogger
  /// Called for every decoded or fallback AeroSpace event line.
  private let handleEvent: (AeroSpaceSubscriptionEvent) -> Void
  /// Current locked controller state.
  private let state = LockedState(State())

  /// Creates one AeroSpace subscription controller.
  init(
    commandRunner: AeroSpaceCommandRunner,
    logger: ProcessLogger,
    handleEvent: @escaping (AeroSpaceSubscriptionEvent) -> Void
  ) {
    self.commandRunner = commandRunner
    self.logger = logger
    self.handleEvent = handleEvent
  }

  /// Starts the long-lived AeroSpace subscription if possible.
  func start() {
    let generation = withLock { state -> UInt64? in
      guard !state.running else { return nil }
      state.running = true
      state.generation &+= 1
      state.outputBuffer.removeAll(keepingCapacity: true)
      state.errorBuffer.removeAll(keepingCapacity: true)
      return state.generation
    }

    guard let generation else { return }

    startProcess(generation: generation)
  }

  /// Stops the subscription process.
  func stop() {
    let subscription = withLock { state -> RunningSubscription? in
      guard state.running else { return nil }
      state.running = false
      state.generation &+= 1
      state.outputBuffer.removeAll(keepingCapacity: true)
      state.errorBuffer.removeAll(keepingCapacity: true)

      let subscription = state.subscription
      state.subscription = nil
      return subscription
    }

    guard let subscription else { return }

    subscription.outputHandle.readabilityHandler = nil
    subscription.errorHandle.readabilityHandler = nil

    if subscription.process.isRunning {
      subscription.process.terminate()
    }

    logger.debug("aerospace subscription stopped")
  }

  /// Starts one concrete `aerospace subscribe` process.
  private func startProcess(generation: UInt64) {
    guard isActive(generation: generation) else { return }

    guard
      let process = commandRunner.makeProcess(
        arguments: AeroSpaceSubscriptionEvent.subscribeArguments)
    else {
      logger.debug("aerospace subscription skipped because executable is unavailable")
      return
    }

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    let outputHandle = outputPipe.fileHandleForReading
    let errorHandle = errorPipe.fileHandleForReading
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    outputHandle.readabilityHandler = { [weak self] handle in
      self?.handleAvailableData(from: handle, stream: .output, generation: generation)
    }
    errorHandle.readabilityHandler = { [weak self] handle in
      self?.handleAvailableData(from: handle, stream: .error, generation: generation)
    }
    process.terminationHandler = { [weak self] process in
      self?.handleTermination(process: process, generation: generation)
    }

    do {
      try process.run()
    } catch {
      outputHandle.readabilityHandler = nil
      errorHandle.readabilityHandler = nil
      logger.debug(
        "failed to start aerospace subscription",
        .field("args", AeroSpaceSubscriptionEvent.subscribeArguments.joined(separator: " ")),
        .field("error", error)
      )
      return
    }

    let subscription = RunningSubscription(
      process: process,
      outputHandle: outputHandle,
      errorHandle: errorHandle
    )

    let shouldKeep = withLock { state -> Bool in
      guard state.running, state.generation == generation, process.isRunning else {
        return false
      }

      state.subscription = subscription
      return true
    }

    guard shouldKeep else {
      outputHandle.readabilityHandler = nil
      errorHandle.readabilityHandler = nil
      if process.isRunning {
        process.terminate()
      }
      return
    }

    logger.debug(
      "aerospace subscription started",
      .field("events", AeroSpaceSubscriptionEvent.subscriptionDescription)
    )
  }

  /// Handles newly available stdout or stderr bytes.
  private func handleAvailableData(
    from handle: FileHandle,
    stream: StreamKind,
    generation: UInt64
  ) {
    guard isActive(generation: generation) else { return }

    let data = handle.availableData
    guard !data.isEmpty else {
      handle.readabilityHandler = nil
      return
    }

    let result = withLock { state -> (lines: [String], droppedBuffer: Bool) in
      switch stream {
      case .output:
        return Self.append(data: data, to: &state.outputBuffer)
      case .error:
        return Self.append(data: data, to: &state.errorBuffer)
      }
    }

    if result.droppedBuffer {
      logger.warn("aerospace subscription stream buffer exceeded limit")
    }

    for line in result.lines {
      switch stream {
      case .output:
        handleOutputLine(line, generation: generation)
      case .error:
        logger.debug("aerospace subscription stderr", .field("line", line))
      }
    }
  }

  /// Handles one complete stdout line from `aerospace subscribe`.
  private func handleOutputLine(_ line: String, generation: UInt64) {
    guard isActive(generation: generation) else { return }

    let event: AeroSpaceSubscriptionEvent
    do {
      event = try JSONDecoder().decode(
        AeroSpaceSubscriptionEvent.self,
        from: Data(line.utf8)
      )
    } catch {
      event = AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.unknown)
      logger.debug(
        "aerospace subscription output was not a known JSON event",
        .field("bytes", line.utf8.count),
        .field("error", error)
      )
    }

    logger.debug(
      "aerospace subscription event received",
      .field("event", event.name)
    )
    handleEvent(event)
  }

  /// Handles process termination.
  private func handleTermination(process: Process, generation: UInt64) {
    let status = process.terminationStatus
    let wasActive = withLock { state -> Bool in
      if state.subscription?.process === process {
        state.subscription?.outputHandle.readabilityHandler = nil
        state.subscription?.errorHandle.readabilityHandler = nil
        state.subscription = nil
        state.outputBuffer.removeAll(keepingCapacity: true)
        state.errorBuffer.removeAll(keepingCapacity: true)
      }

      return state.running && state.generation == generation
    }

    guard wasActive else { return }

    if status == 0 {
      logger.debug("aerospace subscription ended")
    } else {
      logger.warn(
        "aerospace subscription exited",
        .field("status", status)
      )
    }
  }

  /// Appends bytes to a stream buffer and extracts complete lines.
  private static func append(
    data: Data,
    to buffer: inout Data
  ) -> (lines: [String], droppedBuffer: Bool) {
    buffer.append(data)

    var lines: [String] = []
    while let newlineIndex = buffer.firstIndex(of: 0x0A) {
      let lineData = buffer[..<newlineIndex]
      let nextIndex = buffer.index(after: newlineIndex)
      buffer.removeSubrange(buffer.startIndex..<nextIndex)

      var lineBytes = Array(lineData)
      if lineBytes.last == 0x0D {
        lineBytes.removeLast()
      }

      let line = String(decoding: lineBytes, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }
      lines.append(line)
    }

    guard buffer.count <= maxBufferedBytes else {
      buffer.removeAll(keepingCapacity: true)
      return (lines, true)
    }

    return (lines, false)
  }

  /// Returns whether callbacks for the given generation are still valid.
  private func isActive(generation: UInt64) -> Bool {
    withLock { state in
      state.running && state.generation == generation
    }
  }

  /// Runs one closure while holding the controller state lock.
  private func withLock<T>(_ body: (inout State) -> T) -> T {
    state.withLock(body)
  }
}
