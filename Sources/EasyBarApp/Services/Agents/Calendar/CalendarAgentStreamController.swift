import EasyBarShared
import Foundation

/// Shared lifecycle and message handling for calendar-agent stream clients.
///
/// Concrete wrappers only provide the request builder and snapshot sink.
final class CalendarAgentStreamController: @unchecked Sendable {
  private struct LifecycleState {
    var started = false
    var socketPath: String
    var request: CalendarAgentRequest
  }

  /// Human-readable stream label used in logs.
  private let label: String
  /// Returns the current socket path.
  private let socketPath: () -> String
  /// Builds the current subscribe or refresh request.
  private let makeRequest: () -> CalendarAgentRequest
  /// Applies decoded snapshots to the caller state.
  private let applySnapshot: @MainActor @Sendable (EasyBarShared.CalendarAgentSnapshot) -> Void
  /// Clears caller state after errors or disconnects.
  private let clearState: @MainActor @Sendable () -> Void
  /// Metrics key used for this stream.
  private let metricsAgent: MetricsCoordinator.AgentKey
  /// Metrics recorder for agent lifecycle and messages.
  private let metricsCoordinator: MetricsCoordinator
  /// Wake-triggered refresh controller.
  private let wakeRefreshController: AgentWakeRefreshController
  /// Logger used for stream diagnostics.
  private let logger: ProcessLogger

  /// Cached stream state consumed by background socket work.
  private let lifecycleState: LockedState<LifecycleState>

  /// Socket client that owns the calendar-agent stream.
  private lazy var client: AgentSocketClient<CalendarAgentRequest, CalendarAgentMessage> = {
    let metricCallbacks = AgentSocketMetricCallbacks.recording(
      metricsAgent,
      coordinator: metricsCoordinator
    )

    return AgentSocketClient(
      label: label,
      socketPath: { [weak self] in self?.currentSocketPath() ?? "" },
      subscribeRequest: { [weak self] in
        self?.currentRequest() ?? CalendarAgentRequest(command: .ping)
      },
      handleMessage: { [weak self] message, connectionID in
        self?.handle(message, connectionID: connectionID)
      },
      clearState: { [weak self] connectionID in
        self?.handleDisconnectedStateReset(connectionID: connectionID)
      },
      onConnected: metricCallbacks.onConnected,
      onDisconnected: metricCallbacks.onDisconnected,
      onDecodedMessage: metricCallbacks.onDecodedMessage,
      onDecodeError: metricCallbacks.onDecodeError,
      logger: logger.child("socket_client")
    )
  }()

  /// Creates one shared calendar-agent stream controller.
  init(
    label: String,
    metricsAgent: MetricsCoordinator.AgentKey = .calendar,
    socketPath: @escaping () -> String,
    makeRequest: @escaping () -> CalendarAgentRequest,
    applySnapshot: @escaping @MainActor @Sendable (EasyBarShared.CalendarAgentSnapshot) -> Void,
    clearState: @escaping @MainActor @Sendable () -> Void = {},
    metricsCoordinator: MetricsCoordinator = .shared,
    logger: ProcessLogger
  ) {
    self.label = label
    self.metricsAgent = metricsAgent
    self.metricsCoordinator = metricsCoordinator
    self.socketPath = socketPath
    self.makeRequest = makeRequest
    self.applySnapshot = applySnapshot
    self.clearState = clearState
    self.logger = logger
    self.lifecycleState = LockedState(
      LifecycleState(socketPath: socketPath(), request: CalendarAgentRequest(command: .ping))
    )

    wakeRefreshController = AgentWakeRefreshController(
      label: label,
      logger: logger.child("wake_refresh")
    )
  }

  /// Returns whether the stream lifecycle is active.
  var isStarted: Bool {
    return lifecycleState.withLock { $0.started }
  }

  /// Returns whether the stream currently has an active connection.
  var isConnected: Bool {
    return isStarted && client.isConnected
  }

  /// Starts the stream when the calendar agent is enabled.
  func start(enabled: Bool) {
    guard !isStarted else { return }

    guard enabled else {
      logger.debug("\(label) start skipped because agent is disabled")
      return
    }

    updateCachedConnectionInputs(started: true)

    wakeRefreshController.start { [weak self] in
      guard let self, self.isStarted else { return }
      self.refresh()
    }

    logger.debug(
      "starting \(label)",
      .field("socket", socketPath()),
    )
    client.start()
  }

  /// Stops the stream and clears published state.
  func stop() {
    let shouldStop = lifecycleState.withLock { state -> Bool in
      guard state.started else { return false }
      state.started = false
      return true
    }

    guard shouldStop else { return }

    logger.debug("stopping \(label)")

    wakeRefreshController.stop()
    client.stop()
    let clearState = clearState
    Task { @MainActor in
      clearState()
    }
  }

  /// Restarts the stream against the latest config-derived request and socket path.
  func restart(enabled: Bool) {
    stop()
    start(enabled: enabled)
  }

  /// Applies configuration lifecycle changes and returns whether only a refresh is needed.
  func configurationDidChange(
    previousEnabled: Bool,
    previousSocketPath: String,
    enabled: Bool,
    socketPath: String
  ) -> Bool {
    guard isStarted else { return false }
    guard previousEnabled == enabled, previousSocketPath == socketPath else {
      restart(enabled: enabled)
      return false
    }
    return true
  }

  /// Sends one fresh request built from current config and state.
  func refresh() {
    guard isStarted else { return }

    updateCachedConnectionInputs(started: true)

    Task {
      await metricsCoordinator.recordAgentRefresh(metricsAgent)
    }
    client.refresh()
  }

  /// Handles one decoded calendar-agent response.
  private func handle(_ response: CalendarAgentMessage, connectionID: UInt64) {
    guard isStarted, client.isCurrentConnectionGeneration(connectionID) else { return }

    switch response.kind {
    case .snapshot:
      guard let snapshot = response.snapshot else {
        logger.warn("\(label) received snapshot without payload")
        return
      }

      logger.debug(
        "\(label) applied snapshot",
        .field("permission_state", snapshot.permissionState),
        .field("access_granted", snapshot.accessGranted),
        .field("events", snapshot.events.count),
        .field("sections", snapshot.sections.count),
      )

      Task { @MainActor [weak self] in
        guard let self else { return }
        guard self.isStarted, self.client.isCurrentConnectionGeneration(connectionID) else {
          return
        }

        self.applySnapshot(snapshot)
        CalendarAgentEventRelay.shared.noteSnapshotUpdate()
      }

    case .error:
      logger.warn(
        "\(label) received error",
        .field("message", response.message ?? "unknown"),
      )
      Task { @MainActor [weak self] in
        guard let self else { return }
        guard self.isStarted, self.client.isCurrentConnectionGeneration(connectionID) else {
          return
        }
        self.clearState()
      }

    case .version:
      break

    case .pong, .subscribed, .restarting, .created, .updated, .deleted:
      break
    }
  }

  /// Clears published state only for disconnects that occur while the stream is active.
  private func handleDisconnectedStateReset(connectionID: UInt64) {
    guard isStarted, client.isCurrentConnectionGeneration(connectionID) else { return }
    Task { @MainActor [weak self] in
      guard let self else { return }
      guard self.isStarted, self.client.isCurrentConnectionGeneration(connectionID) else {
        return
      }
      self.clearState()
    }
  }

  /// Refreshes the cached request and socket path used by background socket work.
  private func updateCachedConnectionInputs(started: Bool) {
    let socketPath = socketPath()
    let request = makeRequest()
    lifecycleState.withLock { state in
      state.started = started
      state.socketPath = socketPath
      state.request = request
    }
  }

  /// Returns the latest socket path prepared on the stream owner thread.
  private func currentSocketPath() -> String {
    lifecycleState.withLock { $0.socketPath }
  }

  /// Returns the latest request prepared on the stream owner thread.
  private func currentRequest() -> CalendarAgentRequest {
    lifecycleState.withLock { $0.request }
  }
}
