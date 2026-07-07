import EasyBarShared
import Foundation

/// Schedules AeroSpace subscription reconnect attempts.
protocol AeroSpaceReconnectScheduling: Sendable {
  /// Schedules one reconnect action.
  func schedule(_ action: @escaping @Sendable () -> Void)
  /// Cancels any pending reconnect action.
  func cancel()
  /// Resets the reconnect delay sequence.
  func resetDelay()
}

extension BackoffScheduler: AeroSpaceReconnectScheduling {}

/// Creates AeroSpace subscription sessions.
protocol AeroSpaceSubscriptionLaunching: Sendable {
  /// Returns whether a subscription can currently be launched.
  func canLaunchSubscription(arguments: [String]) -> Bool
  /// Creates one subscription session.
  func makeSubscription(arguments: [String]) -> AeroSpaceSubscriptionSession?
}

/// One launchable AeroSpace subscription session.
protocol AeroSpaceSubscriptionSession: AnyObject, Sendable {
  /// Process-style termination status from the finished subscription.
  var terminationStatus: Int32 { get }

  /// Starts the subscription and installs stream/termination callbacks.
  func start(
    onOutputData: @escaping @Sendable (Data) -> Void,
    onErrorData: @escaping @Sendable (Data) -> Void,
    onTermination: @escaping @Sendable (AeroSpaceSubscriptionSession) -> Void
  ) throws

  /// Stops the subscription and releases its resources.
  func stop()

  /// Releases callbacks and file descriptors without changing lifecycle state.
  func invalidate()
}

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

/// Owns the long-lived `aerospace subscribe` process.
final class AeroSpaceSubscriptionController: @unchecked Sendable {
  /// Maximum partial line buffer retained for one process stream.
  private static let maxBufferedBytes = 64 * 1024
  /// Default reconnect delays used after an existing AeroSpace subscription exits.
  private static let defaultReconnectDelays: [TimeInterval] = [0.25, 0.5, 1, 2, 5]

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
    var subscription: AeroSpaceSubscriptionSession?
    var streamBuffers = StreamBuffers()

    mutating func start() -> UInt64? {
      guard !running else { return nil }
      running = true
      generation &+= 1
      clearBuffers()
      return generation
    }

    mutating func stop() -> AeroSpaceSubscriptionSession? {
      guard running else { return nil }
      running = false
      generation &+= 1
      clearBuffers()

      let stoppedSubscription = subscription
      subscription = nil
      return stoppedSubscription
    }

    mutating func attach(
      _ newSubscription: AeroSpaceSubscriptionSession,
      generation: UInt64
    ) -> Bool {
      guard running, self.generation == generation else {
        return false
      }

      subscription = newSubscription
      return true
    }

    mutating func detach(
      subscription: AeroSpaceSubscriptionSession,
      generation: UInt64
    ) -> (wasActive: Bool, subscription: AeroSpaceSubscriptionSession?) {
      let matchedSubscription = self.subscription === subscription ? self.subscription : nil
      if matchedSubscription != nil {
        self.subscription = nil
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

  /// Runner used to locate the AeroSpace CLI.
  private let commandRunner: AeroSpaceCommandRunner
  /// Logger used for subscription diagnostics.
  private let logger: ProcessLogger
  /// Creates concrete subscription sessions.
  private let subscriptionLauncher: any AeroSpaceSubscriptionLaunching
  /// Scheduler used to reconnect after subscription exits.
  private let reconnectScheduler: any AeroSpaceReconnectScheduling
  /// Called for every decoded or fallback AeroSpace event line.
  private let handleEvent: (AeroSpaceSubscriptionEvent) -> Void
  /// Current locked controller state.
  private let state = LockedState(State())

  /// Creates one AeroSpace subscription controller.
  init(
    commandRunner: AeroSpaceCommandRunner,
    logger: ProcessLogger,
    subscriptionLauncher: (any AeroSpaceSubscriptionLaunching)? = nil,
    reconnectScheduler: (any AeroSpaceReconnectScheduling)? = nil,
    reconnectDelays: [TimeInterval] = AeroSpaceSubscriptionController.defaultReconnectDelays,
    sleeper: any AsyncSleeper = TaskSleeper(),
    handleEvent: @escaping (AeroSpaceSubscriptionEvent) -> Void
  ) {
    self.commandRunner = commandRunner
    self.logger = logger
    self.subscriptionLauncher =
      subscriptionLauncher
      ?? ProcessAeroSpaceSubscriptionLauncher(commandRunner: commandRunner)
    self.reconnectScheduler =
      reconnectScheduler
      ?? BackoffScheduler(
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
    subscription?.stop()

    logger.debug("aerospace subscription stopped")
  }

  /// Starts one concrete `aerospace subscribe` session.
  private func startProcess(generation: UInt64) {
    guard isActive(generation: generation) else { return }

    let arguments = AeroSpaceSubscriptionEvent.subscribeArguments
    guard let subscription = subscriptionLauncher.makeSubscription(arguments: arguments) else {
      logger.debug("aerospace subscription skipped because executable is unavailable")
      return
    }

    let shouldStart = withLock { state in
      state.attach(subscription, generation: generation)
    }

    guard shouldStart else {
      subscription.stop()
      return
    }

    do {
      try subscription.start(
        onOutputData: { [weak self] data in
          self?.handleAvailableData(data, stream: .output, generation: generation)
        },
        onErrorData: { [weak self] data in
          self?.handleAvailableData(data, stream: .error, generation: generation)
        },
        onTermination: { [weak self] subscription in
          self?.handleTermination(subscription: subscription, generation: generation)
        }
      )
    } catch {
      let result = withLock { state in
        state.detach(subscription: subscription, generation: generation)
      }
      result.subscription?.invalidate()
      logger.debug(
        "failed to start aerospace subscription",
        .field("args", arguments.joined(separator: " ")),
        .field("error", error)
      )
      scheduleReconnect(generation: generation)
      return
    }

    logger.debug(
      "aerospace subscription started",
      .field("events", AeroSpaceSubscriptionEvent.subscriptionDescription)
    )
  }

  /// Handles newly available stdout or stderr bytes.
  private func handleAvailableData(
    _ data: Data,
    stream: StreamKind,
    generation: UInt64
  ) {
    guard isActive(generation: generation), !data.isEmpty else { return }

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
  private func handleTermination(
    subscription: AeroSpaceSubscriptionSession,
    generation: UInt64
  ) {
    let status = subscription.terminationStatus
    let result = withLock { state in
      state.detach(subscription: subscription, generation: generation)
    }

    result.subscription?.invalidate()

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
    guard
      subscriptionLauncher.canLaunchSubscription(
        arguments: AeroSpaceSubscriptionEvent.subscribeArguments
      )
    else {
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
