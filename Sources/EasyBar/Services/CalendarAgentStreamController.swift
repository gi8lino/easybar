import EasyBarShared
import Foundation

/// Shared lifecycle and message handling for calendar-agent stream clients.
///
/// Concrete wrappers only provide the request builder and snapshot sink.
final class CalendarAgentStreamController {
  private let label: String
  private let socketPath: () -> String
  private let makeRequest: () -> CalendarAgentRequest?
  private let applySnapshot: (EasyBarShared.CalendarAgentSnapshot) -> Void

  private let decoder = JSONDecoder()
  private var client: CalendarAgentSocketClient?
  private var started = false

  /// Creates one shared calendar-agent stream controller.
  init(
    label: String,
    socketPath: @escaping () -> String,
    makeRequest: @escaping () -> CalendarAgentRequest?,
    applySnapshot: @escaping (EasyBarShared.CalendarAgentSnapshot) -> Void
  ) {
    self.label = label
    self.socketPath = socketPath
    self.makeRequest = makeRequest
    self.applySnapshot = applySnapshot
    decoder.dateDecodingStrategy = .iso8601
  }

  /// Returns whether the stream currently has an active client.
  var isConnected: Bool {
    started && client != nil
  }

  /// Starts the stream when the calendar agent is enabled.
  func start(enabled: Bool) {
    guard !started else { return }

    guard enabled else {
      Logger.info("\(label) start skipped because agent is disabled")
      return
    }

    started = true

    let resolvedSocketPath = socketPath()
    Logger.info("starting \(label) socket=\(resolvedSocketPath)")

    let client = CalendarAgentSocketClient(socketPath: resolvedSocketPath)
    client.onMessage = { [weak self] line in
      self?.handleMessage(line)
    }
    client.onDisconnect = { [weak self] in
      self?.handleDisconnect()
    }

    self.client = client
    client.start()

    refresh()
  }

  /// Stops the stream and releases the current socket client.
  func stop() {
    guard started else { return }

    Logger.info("stopping \(label)")
    started = false
    client?.stop()
    client = nil
  }

  /// Sends one fresh request built from current config and state.
  func refresh() {
    guard let client, let request = makeRequest() else { return }
    client.send(request)
  }

  /// Handles one raw line received from the calendar agent.
  private func handleMessage(_ line: String) {
    Logger.debug("\(label) received line=\(line)")

    guard let data = line.data(using: .utf8) else {
      Logger.warn("\(label) received invalid utf8")
      return
    }

    do {
      let response = try decoder.decode(CalendarAgentMessage.self, from: data)
      handleResponse(response)
    } catch {
      Logger.warn("\(label) failed decoding response error=\(error)")
    }
  }

  /// Handles one decoded calendar-agent response.
  private func handleResponse(_ response: CalendarAgentMessage) {
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

    case .pong, .subscribed, .created, .updated, .deleted:
      break
    }
  }

  /// Handles one stream disconnect.
  private func handleDisconnect() {
    Logger.warn("\(label) disconnected")
    started = false
    client = nil
  }
}
