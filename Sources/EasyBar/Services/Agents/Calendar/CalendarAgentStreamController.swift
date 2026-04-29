import EasyBarShared
import Foundation

/// Shared lifecycle and message handling for calendar-agent stream clients.
///
/// Concrete wrappers only provide the request builder and snapshot sink.
final class CalendarAgentStreamController {
  private let label: String
  private let socketPath: () -> String
  private let makeRequest: () -> CalendarAgentRequest
  private let applySnapshot: (EasyBarShared.CalendarAgentSnapshot) -> Void
  private let clearState: () -> Void
  private let metricsAgent: MetricsCoordinator.AgentKey
  private let wakeRefreshController: AgentWakeRefreshController
  private let logger: ProcessLogger

  private var started = false

  private lazy var client = AgentSocketClient<CalendarAgentRequest, CalendarAgentMessage>(
    label: label,
    socketPath: socketPath,
    subscribeRequest: { [weak self] in
      self?.makeRequest() ?? CalendarAgentRequest(command: .ping)
    },
    handleMessage: { [weak self] message in
      self?.handle(message)
    },
    clearState: { [weak self] in
      self?.handleDisconnectedStateReset()
    },
    onConnected: { [weak self] in
      guard let self else { return }
      MetricsCoordinator.shared.recordAgentConnected(self.metricsAgent)
    },
    onDisconnected: { [weak self] in
      guard let self else { return }
      MetricsCoordinator.shared.recordAgentDisconnected(self.metricsAgent)
    },
    onDecodedMessage: { [weak self] in
      guard let self else { return }
      MetricsCoordinator.shared.recordAgentMessage(self.metricsAgent)
    },
    onDecodeError: { [weak self] in
      guard let self else { return }
      MetricsCoordinator.shared.recordAgentDecodeError(self.metricsAgent)
    },
    logger: logger.child("socket_client")
  )

  /// Creates one shared calendar-agent stream controller.
  init(
    label: String,
    metricsAgent: MetricsCoordinator.AgentKey = .calendar,
    socketPath: @escaping () -> String,
    makeRequest: @escaping () -> CalendarAgentRequest,
    applySnapshot: @escaping (EasyBarShared.CalendarAgentSnapshot) -> Void,
    clearState: @escaping () -> Void = {},
    logger: ProcessLogger
  ) {
    self.label = label
    self.metricsAgent = metricsAgent
    self.socketPath = socketPath
    self.makeRequest = makeRequest
    self.applySnapshot = applySnapshot
    self.clearState = clearState
    self.logger = logger

    wakeRefreshController = AgentWakeRefreshController(
      label: label,
      logger: logger.child("wake_refresh")
    )
  }

  /// Returns whether the stream currently has an active connection.
  var isConnected: Bool {
    started && client.isConnected
  }

  /// Starts the stream when the calendar agent is enabled.
  func start(enabled: Bool) {
    guard !started else { return }

    guard enabled else {
      logger.info("\(label) start skipped because agent is disabled")
      return
    }

    started = true

    wakeRefreshController.start { [weak self] in
      guard let self, self.started else { return }
      self.refresh()
    }

    logger.info(
      "starting \(label)",
      .field("socket", socketPath()),
    )
    client.start()
  }

  /// Stops the stream and clears published state.
  func stop() {
    guard started else { return }

    logger.info("stopping \(label)")

    started = false
    wakeRefreshController.stop()
    client.stop()
    clearState()
  }

  /// Sends one fresh request built from current config and state.
  func refresh() {
    guard started else { return }

    MetricsCoordinator.shared.recordAgentRefresh(metricsAgent)
    client.refresh()
  }

  /// Handles one decoded calendar-agent response.
  private func handle(_ response: CalendarAgentMessage) {
    guard started else { return }

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

      applySnapshot(snapshot)
      CalendarAgentEventRelay.shared.noteSnapshotUpdate()

    case .error:
      logger.warn(
        "\(label) received error",
        .field("message", response.message ?? "unknown"),
      )
      clearState()

    case .version:
      break

    case .pong, .subscribed, .created, .updated, .deleted:
      break
    }
  }

  /// Clears published state only for disconnects that occur while the stream is active.
  private func handleDisconnectedStateReset() {
    guard started else { return }
    clearState()
  }
}
