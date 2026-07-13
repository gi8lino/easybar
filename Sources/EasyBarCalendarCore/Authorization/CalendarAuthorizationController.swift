import EasyBarShared
import EventKit
import Foundation

/// Coordinates EventKit authorization state, prompts, and retries.
final class CalendarAuthorizationController: @unchecked Sendable {
  /// EventKit store used to inspect and request calendar access.
  private let eventStore: EKEventStore
  /// Thread-safe authorization state cache.
  private let authState: CalendarAuthorizationState
  /// Logger used for authorization diagnostics.
  private let logger: ProcessLogger
  /// Backoff helper for retrying unresolved authorization prompts.
  private let retryBackoff: AuthorizationRetryBackoff

  /// Callback invoked once access is resolved as usable.
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
    retryBackoff = AuthorizationRetryBackoff(logger: logger.child("retry_backoff"))
  }

  /// Starts authorization handling and requests access when needed.
  func start(onResolvedChange: @escaping () -> Void) {
    self.onResolvedChange = onResolvedChange

    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)

    logger.info(
      "calendar agent authorization status before",
      .field("start", "\(authState.describe(status))"),
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
    return authState.effectiveAccessGranted()
  }

  /// Returns the current permission state string.
  func permissionState() -> String {
    return authState.permissionState()
  }

  /// Returns the stable label for a specific EventKit status.
  func describe(_ status: EKAuthorizationStatus) -> String {
    return authState.describe(status)
  }

  /// Requests calendar access when the current state allows it.
  private func requestAccessIfNeeded() {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)

    logger.info(
      "calendar agent access status changed",
      .field("status", authState.describe(status)),
    )

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
            "calendar agent access request failed",
            .field("status", "\(self.authState.describe(newStatus))"),
            .field("error", "\(error)"))
          self.scheduleAuthorizationRetryIfNeeded(for: newStatus)
          return
        }

        self.logger.info(
          "calendar agent access request completed",
          .field("granted", granted),
          .field("status", self.authState.describe(newStatus))
        )

        guard granted else {
          self.scheduleAuthorizationRetryIfNeeded(for: newStatus)
          return
        }

        self.retryBackoff.reset()
        self.authState.markGrantedInProcess()

        Task { @MainActor in
          self.onResolvedChange?()
        }
      }

    case .denied, .restricted, .writeOnly:
      retryBackoff.reset()
      logger.warn(
        "calendar agent access unavailable",
        .field("status", "\(authState.describe(status))"),
      )

    @unknown default:
      retryBackoff.reset()
      logger.warn(
        "calendar agent access status unknown",
        .field("raw", "\(status.rawValue)"),
      )
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
