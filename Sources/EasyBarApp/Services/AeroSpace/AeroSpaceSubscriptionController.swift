import EasyBarShared
import Foundation

/// Owns the long-lived `aerospace subscribe` process.
final class AeroSpaceSubscriptionController: @unchecked Sendable {
  /// Maximum partial line buffer retained for one process stream.
  private static let maxBufferedBytes = 64 * 1024
  /// Default reconnect delays used after an existing AeroSpace subscription exits.
  private static let defaultReconnectDelays: [TimeInterval] = [0.25, 0.5, 1, 2, 5]

  /// One running subscription process and its read handles.
  private final class RunningSubscription: @unchecked Sendable {
    let process: Process
    let outputHandle: FileHandle
    let errorHandle: FileHandle
    private let releaseLock = NSLock()
    private var released = false

    init(process: Process, outputHandle: FileHandle, errorHandle: FileHandle) {
      self.process = process
      self.outputHandle = outputHandle
      self.errorHandle = errorHandle
    }

    func release() {
      guard markReleased() else { return }

      process.terminationHandler = nil
      outputHandle.readabilityHandler = nil
      errorHandle.readabilityHandler = nil

      try? outputHandle.close()
      try? errorHandle.close()
    }

    func terminateAndReleaseOnExit() {
      outputHandle.readabilityHandler = nil
      errorHandle.readabilityHandler = nil
      process.terminationHandler = { [self] _ in
        release()
      }

      guard process.isRunning else {
        release()
        return
      }

      process.terminate()
    }

    private func markReleased() -> Bool {
      releaseLock.lock()
      defer { releaseLock.unlock() }

      guard !released else { return false }
      released = true
      return true
    }
  }

  /// Partial stdout/stderr line buffers for one subscription process.
  private struct StreamBuffers {
    var output = Data()
    var error = Data()

    mutating func clear() {
      output.removeAll(keepingCapacity: true)
      error.removeAll(keepingCapacity: true)
    }

    mutating func append(
      data: Data,
      stream: StreamKind
    ) -> (lines: [String], droppedBuffer: Bool) {
      switch stream {
      case .output:
        return Self.extractLines(appending: data, to: &output)
      case .error:
        return Self.extractLines(appending: data, to: &error)
      }
    }

    private static func extractLines(
      appending data: Data,
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
  }

  /// Locked lifecycle state for the subscription process.
  private struct State {
    var running = false
    var generation: UInt64 = 0
    var subscription: RunningSubscription?
    var streamBuffers = StreamBuffers()

    mutating func start() -> UInt64? {
      guard !running else { return nil }
      running = true
      generation &+= 1
      clearBuffers()
      return generation
    }

    mutating func stop() -> RunningSubscription? {
      guard running else { return nil }
      running = false
      generation &+= 1
      clearBuffers()

      let stoppedSubscription = subscription
      subscription = nil
      return stoppedSubscription
    }

    mutating func attach(_ newSubscription: RunningSubscription, generation: UInt64) -> Bool {
      guard running, self.generation == generation, newSubscription.process.isRunning else {
        return false
      }

      subscription = newSubscription
      return true
    }

    mutating func detach(
      process: Process,
      generation: UInt64
    ) -> (wasActive: Bool, subscription: RunningSubscription?) {
      let matchedSubscription = subscription?.process === process ? subscription : nil
      if matchedSubscription != nil {
        subscription = nil
        clearBuffers()
      }

      return (running && self.generation == generation, matchedSubscription)
    }

    mutating func append(
      data: Data,
      stream: StreamKind
    ) -> (lines: [String], droppedBuffer: Bool) {
      streamBuffers.append(data: data, stream: stream)
    }

    private mutating func clearBuffers() {
      streamBuffers.clear()
    }
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
  /// Scheduler used to reconnect after subscription exits.
  private let reconnectScheduler: BackoffScheduler
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
    self.reconnectScheduler = BackoffScheduler(
      label: "aerospace subscription reconnect",
      delays: reconnectDelays,
      logger: logger,
      sleeper: sleeper
    )
    self.handleEvent = handleEvent
  }

  /// Starts the long-lived AeroSpace subscription if possible.
  func start() {
    let generation = withLock { state in state.start() }

    guard let generation else { return }

    reconnectScheduler.cancel()
    startProcess(generation: generation)
  }

  /// Stops the subscription process.
  func stop() {
    let subscription = withLock { state in state.stop() }

    reconnectScheduler.cancel()
    guard let subscription else { return }

    subscription.terminateAndReleaseOnExit()

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
      RunningSubscription(
        process: process,
        outputHandle: outputHandle,
        errorHandle: errorHandle
      ).release()
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

    let shouldKeep = withLock { state in
      state.attach(subscription, generation: generation)
    }

    guard shouldKeep else {
      subscription.terminateAndReleaseOnExit()
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

    let result = withLock { state in
      state.append(data: data, stream: stream)
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
    let result = withLock { state in
      state.detach(process: process, generation: generation)
    }

    result.subscription?.release()

    guard result.wasActive else { return }

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

    reconnectScheduler.schedule { [weak self] in
      guard let self else { return }
      guard self.isActive(generation: generation) else { return }
      self.startProcess(generation: generation)
    }
  }

  /// Resets reconnect backoff after the event stream proves healthy.
  private func resetReconnectBackoff(generation: UInt64) {
    guard isActive(generation: generation) else { return }
    reconnectScheduler.resetDelay()
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
