import EasyBarShared
import EventKit
import Foundation

/// Coordinates EventKit authorization state, prompts, and retries.
final class CalendarAuthorizationController: @unchecked Sendable {
  /// Thread-safe authorization state cache.
  private let authState: CalendarAuthorizationState
  /// Logger used for authorization diagnostics.
  private let logger: ProcessLogger
  /// Current EventKit authorization status provider.
  private let authorizationStatus: () -> EKAuthorizationStatus
  /// EventKit access-request adapter.
  private let requestAccess: (@escaping @Sendable (Bool, Error?) -> Void) -> Void
  /// Generation-scoped callback and retry ownership.
  private let lifecycle: AuthorizationLifecycle

  /// Creates one calendar authorization controller.
  init(
    eventStore: EKEventStore,
    authState: CalendarAuthorizationState,
    logger: ProcessLogger,
    authorizationStatus: (() -> EKAuthorizationStatus)? = nil,
    requestAccess: ((@escaping @Sendable (Bool, Error?) -> Void) -> Void)? = nil
  ) {
    self.authState = authState
    self.logger = logger
    self.authorizationStatus =
      authorizationStatus ?? {
        EKEventStore.authorizationStatus(for: .event)
      }
    self.requestAccess =
      requestAccess ?? { completion in
        eventStore.requestFullAccessToEvents(completion: completion)
      }
    lifecycle = AuthorizationLifecycle(logger: logger)
  }

  /// Starts authorization handling and requests access when needed.
  func start(onResolvedChange: @escaping () -> Void) {
    let session = lifecycle.start(onChange: onResolvedChange)

    let status = authorizationStatus()
    authState.setStatus(status)

    logger.info(
      "calendar agent authorization status before",
      .field("start", "\(authState.describe(status))"),
    )

    requestAccessIfNeeded(for: session)
  }

  /// Stops callbacks and pending retry work for the current generation.
  func stop() {
    lifecycle.stop()
  }

  /// Refreshes the stored status from EventKit.
  func refreshStatus() {
    authState.setStatus(authorizationStatus())
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

  /// Requests calendar access when the current generation still owns the flow.
  private func requestAccessIfNeeded(for session: AuthorizationLifecycle.Session) {
    guard lifecycle.isCurrent(session) else { return }

    let status = authorizationStatus()
    authState.setStatus(status)

    logger.info(
      "calendar agent access status changed",
      .field("status", authState.describe(status)),
    )

    switch status {
    case .authorized, .fullAccess:
      lifecycle.resetRetry(for: session)
      logger.info("calendar agent access already granted")
      lifecycle.notify(session)

    case .notDetermined:
      logger.info("requesting calendar full access")

      requestAccess { [weak self, weak session] granted, error in
        guard let self, let session, self.lifecycle.isCurrent(session) else { return }

        let newStatus = self.authorizationStatus()
        self.authState.setStatus(newStatus)

        if let error {
          self.logger.error(
            "calendar agent access request failed",
            .field("status", "\(self.authState.describe(newStatus))"),
            .field("error", "\(error)"))
          self.scheduleAuthorizationRetryIfNeeded(for: newStatus, session: session)
          self.notifyResolvedChange(for: session)
          return
        }

        self.logger.info(
          "calendar agent access request completed",
          .field("granted", granted),
          .field("status", self.authState.describe(newStatus))
        )

        guard granted else {
          self.scheduleAuthorizationRetryIfNeeded(for: newStatus, session: session)
          self.notifyResolvedChange(for: session)
          return
        }

        self.lifecycle.resetRetry(for: session)
        self.authState.markGrantedInProcess()
        self.notifyResolvedChange(for: session)
      }

    case .denied, .restricted, .writeOnly:
      lifecycle.resetRetry(for: session)
      logger.warn(
        "calendar agent access unavailable",
        .field("status", "\(authState.describe(status))"),
      )
      lifecycle.notify(session)

    @unknown default:
      lifecycle.resetRetry(for: session)
      logger.warn(
        "calendar agent access status unknown",
        .field("raw", "\(status.rawValue)"),
      )
      lifecycle.notify(session)
    }
  }

  /// Delivers one asynchronous permission-result notification on the main actor.
  private func notifyResolvedChange(for session: AuthorizationLifecycle.Session) {
    Task { @MainActor [weak self, weak session] in
      guard let self, let session else { return }
      self.lifecycle.notify(session)
    }
  }

  /// Schedules one follow-up access request while authorization is unresolved.
  private func scheduleAuthorizationRetryIfNeeded(
    for status: EKAuthorizationStatus,
    session: AuthorizationLifecycle.Session
  ) {
    guard status == .notDetermined else {
      lifecycle.resetRetry(for: session)
      return
    }

    lifecycle.scheduleRetry(for: session) { [weak self] session in
      self?.requestAccessIfNeeded(for: session)
    }
  }
}
