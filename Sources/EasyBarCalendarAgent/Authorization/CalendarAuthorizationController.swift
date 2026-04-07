import EasyBarShared
import EventKit
import Foundation

final class CalendarAuthorizationController {
  private let eventStore: EKEventStore
  private let authState: CalendarAuthorizationState
  private let logger: ProcessLogger
  private let retryBackoff: AuthorizationRetryBackoff

  private var onResolvedChange: (() -> Void)?

  /// Creates one calendar authorization controller.
  init(
    eventStore: EKEventStore,
    authState: CalendarAuthorizationState,
    logger: ProcessLogger
  ) {
    self.eventStore = eventStore
    self.authState = authState
    self.logger = logger
    self.retryBackoff = AuthorizationRetryBackoff(debugLog: logger.debug)
  }

  /// Starts authorization handling and requests access when needed.
  func start(onResolvedChange: @escaping () -> Void) {
    self.onResolvedChange = onResolvedChange

    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)
    logger.info(
      "calendar agent authorization status before start=\(authState.describe(status))"
    )

    requestAccessIfNeeded()
  }

  /// Stops any pending retry work.
  func stop() {
    retryBackoff.reset()
    onResolvedChange = nil
  }

  /// Refreshes the stored status from EventKit.
  func refreshStatus() {
    authState.setStatus(EKEventStore.authorizationStatus(for: .event))
  }

  /// Returns whether calendar access is currently effective.
  func effectiveAccessGranted() -> Bool {
    authState.effectiveAccessGranted()
  }

  /// Returns the current permission state string.
  func permissionState() -> String {
    authState.permissionState()
  }

  /// Returns the stable label for a specific EventKit status.
  func describe(_ status: EKAuthorizationStatus) -> String {
    authState.describe(status)
  }

  /// Requests calendar access when the current state allows it.
  private func requestAccessIfNeeded() {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)
    logger.info("calendar agent access status=\(authState.describe(status))")

    switch status {
    case .authorized, .fullAccess:
      retryBackoff.reset()
      logger.info("calendar agent access already granted")
      onResolvedChange?()

    case .notDetermined:
      logger.info("requesting calendar full access")
      eventStore.requestFullAccessToEvents { [weak self] granted, error in
        guard let self else { return }

        let newStatus = EKEventStore.authorizationStatus(for: .event)
        self.authState.setStatus(newStatus)

        if let error {
          self.logger.error(
            "calendar agent access request failed status=\(self.authState.describe(newStatus)) error=\(error)"
          )
          self.scheduleAuthorizationRetryIfNeeded(for: newStatus)
          return
        }

        self.logger.info(
          "calendar agent access request completed granted=\(granted) status=\(self.authState.describe(newStatus))"
        )

        guard granted else {
          self.scheduleAuthorizationRetryIfNeeded(for: newStatus)
          return
        }

        self.retryBackoff.reset()
        self.authState.markGrantedInProcess()
        DispatchQueue.main.async {
          self.onResolvedChange?()
        }
      }

      scheduleAuthorizationRetryIfNeeded(for: status)

    case .denied, .restricted, .writeOnly:
      retryBackoff.reset()
      logger.warn("calendar agent access unavailable status=\(authState.describe(status))")

    @unknown default:
      retryBackoff.reset()
      logger.warn("calendar agent access status unknown raw=\(status.rawValue)")
    }
  }

  /// Schedules one follow-up access request while authorization is unresolved.
  private func scheduleAuthorizationRetryIfNeeded(for status: EKAuthorizationStatus) {
    guard status == .notDetermined else {
      retryBackoff.reset()
      return
    }

    retryBackoff.schedule { [weak self] in
      self?.requestAccessIfNeeded()
    }
  }
}
