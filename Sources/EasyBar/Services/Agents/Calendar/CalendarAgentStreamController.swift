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

  private var started = false
  private let eventObserver = EasyBarEventObserver()
  private let refreshQueue = DispatchQueue(label: "easybar.calendar-agent.refresh")
  private var pendingWakeRefreshWorkItem: DispatchWorkItem?

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
    debugLog: easybarLog.debug,
    infoLog: easybarLog.info,
    warnLog: easybarLog.warn,
    errorLog: easybarLog.error
  )

  /// Creates one shared calendar-agent stream controller.
  init(
    label: String,
    metricsAgent: MetricsCoordinator.AgentKey = .calendar,
    socketPath: @escaping () -> String,
    makeRequest: @escaping () -> CalendarAgentRequest,
    applySnapshot: @escaping (EasyBarShared.CalendarAgentSnapshot) -> Void,
    clearState: @escaping () -> Void = {}
  ) {
    self.label = label
    self.metricsAgent = metricsAgent
    self.socketPath = socketPath
    self.makeRequest = makeRequest
    self.applySnapshot = applySnapshot
    self.clearState = clearState
  }

  /// Returns whether the stream currently has an active connection.
  var isConnected: Bool {
    started && client.isConnected
  }

  /// Starts the stream when the calendar agent is enabled.
  func start(enabled: Bool) {
    guard !started else { return }

    guard enabled else {
      easybarLog.info("\(label) start skipped because agent is disabled")
      return
    }

    started = true
    startEventObserver()
    easybarLog.info("starting \(label) socket=\(socketPath())")
    client.start()
  }

  /// Stops the stream and clears published state.
  func stop() {
    guard started else { return }

    easybarLog.info("stopping \(label)")
    started = false
    pendingWakeRefreshWorkItem?.cancel()
    pendingWakeRefreshWorkItem = nil
    eventObserver.stop()
    client.stop()
    clearState()
  }

  /// Sends one fresh request built from current config and state.
  func refresh() {
    guard started else { return }
    MetricsCoordinator.shared.recordAgentRefresh(metricsAgent)
    client.refresh()
  }

  /// Starts shared app-event observation needed by the calendar agent streams.
  private func startEventObserver() {
    eventObserver.start { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }
      guard event == .systemWoke else { return }

      self.scheduleWakeRefresh()
    }
  }

  /// Coalesces wake-triggered refresh work into one refresh request.
  private func scheduleWakeRefresh() {
    guard started else { return }
    pendingWakeRefreshWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      easybarLog.debug("\(self.label) refreshing after system_woke")
      self.refresh()
    }

    pendingWakeRefreshWorkItem = workItem
    refreshQueue.asyncAfter(deadline: .now() + 0.20, execute: workItem)
  }

  /// Handles one decoded calendar-agent response.
  private func handle(_ response: CalendarAgentMessage) {
    guard started else { return }

    switch response.kind {
    case .snapshot:
      guard let snapshot = response.snapshot else {
        easybarLog.warn("\(label) received snapshot without payload")
        return
      }

      easybarLog.debug(
        "\(label) applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
      )
      applySnapshot(snapshot)
      CalendarAgentEventRelay.shared.noteSnapshotUpdate()

    case .error:
      easybarLog.warn("\(label) received error message=\(response.message ?? "unknown")")
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
