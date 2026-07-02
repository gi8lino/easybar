import EasyBarShared
import Foundation

/// Owns the long-lived `aerospace subscribe` process.
final class AeroSpaceSubscriptionController: @unchecked Sendable {
  /// Maximum partial line buffer retained for one process stream.
  private static let maxBufferedBytes = 64 * 1024
  /// Default reconnect delays used after an existing AeroSpace subscription exits.
  private static let defaultReconnectDelays: [TimeInterval] = [0.25, 0.5, 1, 2, 5]

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
    var reconnectTask: Task<Void, Never>?
    var reconnectAttempt = 0
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
  /// Bounded reconnect delays used when the subscription process exits.
  private let reconnectDelays: [TimeInterval]
  /// Sleeper used for reconnect delays.
  private let sleeper: any AsyncSleeper
  /// Called for every decoded or fallback AeroSpace event line.
  private let handleEvent: (AeroSpaceSubscriptionEvent) -> Void
  /// Current locked controller state.
  private let state = LockedState(State())

  /// Creates one AeroSpace subscription controller.
  init(
    commandRunner: AeroSpaceCommandRunner,
    logger: ProcessLogger,
    reconnectDelays: [TimeInterval] = AeroSpaceSubscriptionController.defaultReconnectDelays,
    sleeper: any AsyncSleeper = TaskSleeper(),
    handleEvent: @escaping (AeroSpaceSubscriptionEvent) -> Void
  ) {
    self.commandRunner = commandRunner
    self.logger = logger
    self.reconnectDelays = reconnectDelays
    self.sleeper = sleeper
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
      state.reconnectTask?.cancel()
      state.reconnectTask = nil
      state.reconnectAttempt = 0
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
      state.reconnectTask?.cancel()
      state.reconnectTask = nil
      state.reconnectAttempt = 0

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
      scheduleReconnect(generation: generation)
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
    resetReconnectBackoff(generation: generation)
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

    scheduleReconnect(generation: generation)
  }

  /// Schedules a bounded reconnect attempt when AeroSpace still appears installed.
  private func scheduleReconnect(generation: UInt64) {
    guard isActive(generation: generation) else { return }
    guard commandRunner.makeProcess(arguments: AeroSpaceSubscriptionEvent.subscribeArguments) != nil else {
      logger.debug("aerospace subscription reconnect skipped because executable is unavailable")
      return
    }

    let delay = withLock { state -> TimeInterval? in
      guard state.running, state.generation == generation, state.reconnectTask == nil else {
        return nil
      }

      let delay = reconnectDelay(for: state.reconnectAttempt)
      state.reconnectAttempt += 1
      return delay
    }

    guard let delay else { return }

    logger.warn(
      "aerospace subscription reconnect scheduled",
      .field("delay", "\(delay)")
    )

    let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
    let sleeper = sleeper
    let task = Task { [weak self] in
      do {
        try await sleeper.sleep(nanoseconds: nanoseconds)
      } catch {
        return
      }

      guard let self else { return }
      guard self.clearReconnectTask(generation: generation) else { return }
      self.startProcess(generation: generation)
    }

    let shouldCancel = withLock { state -> Bool in
      guard state.running, state.generation == generation, state.reconnectTask == nil else {
        return true
      }

      state.reconnectTask = task
      return false
    }

    if shouldCancel {
      task.cancel()
    }
  }

  /// Clears the pending reconnect task if it still belongs to this generation.
  private func clearReconnectTask(generation: UInt64) -> Bool {
    withLock { state -> Bool in
      guard state.running, state.generation == generation, state.reconnectTask != nil else {
        return false
      }

      state.reconnectTask = nil
      return true
    }
  }

  /// Resets reconnect backoff after the event stream proves healthy.
  private func resetReconnectBackoff(generation: UInt64) {
    withLock { state in
      guard state.running, state.generation == generation else { return }
      state.reconnectAttempt = 0
    }
  }

  /// Returns the capped reconnect delay for one failed subscription generation.
  private func reconnectDelay(for attempt: Int) -> TimeInterval {
    guard !reconnectDelays.isEmpty else { return 0 }
    return reconnectDelays[min(attempt, reconnectDelays.count - 1)]
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
