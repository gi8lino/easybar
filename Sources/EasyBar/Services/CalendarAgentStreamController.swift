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
      self?.clearState()
    },
    debugLog: Logger.debug,
    infoLog: Logger.info,
    warnLog: Logger.warn,
    errorLog: Logger.error
  )

  /// Creates one shared calendar-agent stream controller.
  init(
    label: String,
    socketPath: @escaping () -> String,
    makeRequest: @escaping () -> CalendarAgentRequest,
    applySnapshot: @escaping (EasyBarShared.CalendarAgentSnapshot) -> Void,
    clearState: @escaping () -> Void = {}
  ) {
    self.label = label
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
      Logger.info("\(label) start skipped because agent is disabled")
      return
    }

    started = true
    Logger.info("starting \(label) socket=\(socketPath())")
    client.start()
  }

  /// Stops the stream and clears published state.
  func stop() {
    guard started else { return }

    Logger.info("stopping \(label)")
    started = false
    client.stop()
  }

  /// Sends one fresh request built from current config and state.
  func refresh() {
    guard started else { return }
    client.refresh()
  }

  /// Handles one decoded calendar-agent response.
  private func handle(_ response: CalendarAgentMessage) {
    switch response.kind {
    case .snapshot:
      guard let snapshot = response.snapshot else {
        Logger.warn("\(label) received snapshot without payload")
        return
      }

      Logger.debug(
        "\(label) applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
      )
      applySnapshot(snapshot)

    case .error:
      Logger.warn("\(label) received error message=\(response.message ?? "unknown")")
      clearState()

    case .pong, .subscribed, .created, .updated, .deleted:
      break
    }
  }
}
