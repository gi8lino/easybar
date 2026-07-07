import EasyBarShared
import Foundation

/// Owns the long-lived `aerospace subscribe` process.
///
/// Sendability is guarded by `LockedState`; process session ownership,
/// generation checks, reconnect queue state, and stream buffering are serialized
/// before callbacks can observe or mutate them.
final class AeroSpaceSubscriptionController: @unchecked Sendable {
  /// Default reconnect delays used after an existing AeroSpace subscription exits.
  private static let defaultReconnectDelays: [TimeInterval] = [0.25, 0.5, 1, 2, 5]

  /// Locked lifecycle state for the subscription process.
  private struct State {
    var running = false
    var generation: UInt64 = 0
    var subscription: AeroSpaceSubscriptionSession?
    var streamBuffer = AeroSpaceSubscriptionStreamBuffer()

    mutating func start() -> UInt64? {
      guard !running else { return nil }
      running = true
      generation &+= 1
      clearBuffer()
      return generation
    }

    mutating func stop() -> AeroSpaceSubscriptionSession? {
      guard running else { return nil }
      running = false
      generation &+= 1
      clearBuffer()

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
        clearBuffer()
      }

      return (running && self.generation == generation, matchedSubscription)
    }

    mutating func append(
      data: Data,
      stream: AeroSpaceSubscriptionStreamKind
    ) -> (lines: [String], droppedBuffer: Bool) {
      streamBuffer.append(data: data, stream: stream)
    }

    private mutating func clearBuffer() {
      streamBuffer.clear()
    }
  }

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
    stream: AeroSpaceSubscriptionStreamKind,
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
