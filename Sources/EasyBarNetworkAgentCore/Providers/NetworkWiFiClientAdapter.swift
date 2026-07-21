@preconcurrency import CoreWLAN

/// Narrow CoreWLAN client surface used by the monitor and its lifecycle tests.
@MainActor
protocol NetworkWiFiClientAdapter: AnyObject {
  var delegate: CWEventDelegate? { get set }

  func startMonitoringEvent(with eventType: CWEventType) throws
  func stopMonitoringAllEvents() throws
  func interface() -> CWInterface?
}

/// Production adapter around the process-wide CoreWLAN client.
@MainActor
final class CoreWLANClientAdapter: NetworkWiFiClientAdapter {
  private let client: CWWiFiClient

  init(client: CWWiFiClient = .shared()) {
    self.client = client
  }

  var delegate: CWEventDelegate? {
    get { client.delegate as? CWEventDelegate }
    set { client.delegate = newValue }
  }

  func startMonitoringEvent(with eventType: CWEventType) throws {
    try client.startMonitoringEvent(with: eventType)
  }

  func stopMonitoringAllEvents() throws {
    try client.stopMonitoringAllEvents()
  }

  func interface() -> CWInterface? {
    client.interface()
  }
}
