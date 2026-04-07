import CoreLocation
import EasyBarShared
import Foundation

final class NetworkLocationAuthorizationController: NSObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private let authState = NetworkAuthorizationState()
  private let componentName: String
  private let logger: ProcessLogger
  private let retryBackoff: AuthorizationRetryBackoff
  private weak var promptPresenter: NetworkAuthorizationPromptPresenter?

  private var onChange: (() -> Void)?
  private var presentedAuthorizationPrompt = false

  /// Creates one location authorization controller that logs through the provided logger.
  init(
    componentName: String,
    logger: ProcessLogger,
    promptPresenter: NetworkAuthorizationPromptPresenter? = nil
  ) {
    self.componentName = componentName
    self.logger = logger
    self.promptPresenter = promptPresenter
    retryBackoff = AuthorizationRetryBackoff(debugLog: logger.debug)
    super.init()
  }

  /// Starts tracking and requesting location authorization when needed.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    locationManager.delegate = self

    let status = locationManager.authorizationStatus
    authState.setStatus(status)
    logger.info(
      "\(componentName) authorization status before start=\(authState.permissionState())"
    )

    requestAccessIfNeeded()
  }

  /// Stops authorization callbacks.
  func stop() {
    retryBackoff.reset()
    restoreAccessoryModeIfNeeded()
    locationManager.delegate = nil
    onChange = nil
  }

  /// Returns whether location access is currently authorized.
  func isAuthorized() -> Bool {
    authState.isAuthorized()
  }

  /// Returns the current permission label.
  func permissionState() -> String {
    authState.permissionState()
  }

  /// Handles one location authorization change.
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      self.authState.setStatus(status)
      self.logger.info(
        "\(self.componentName) authorization changed status=\(self.authState.permissionState())"
      )
      self.handleAuthorizationStateChange(status)
      self.onChange?()
    }
  }

  /// Requests location access when the current state allows it.
  private func requestAccessIfNeeded() {
    let status = locationManager.authorizationStatus
    authState.setStatus(status)
    logger.info("\(componentName) access status=\(authState.permissionState())")

    switch status {
    case .authorized, .authorizedAlways, .authorizedWhenInUse:
      retryBackoff.reset()
      restoreAccessoryModeIfNeeded()
      logger.info("\(componentName) access already granted")
      onChange?()

    case .notDetermined:
      prepareAuthorizationPromptIfNeeded()
      logger.info("requesting \(componentName) when-in-use access")
      locationManager.requestWhenInUseAuthorization()
      scheduleRetry()

    case .denied, .restricted:
      retryBackoff.reset()
      restoreAccessoryModeIfNeeded()
      logger.warn("\(componentName) access unavailable status=\(authState.permissionState())")

    @unknown default:
      retryBackoff.reset()
      restoreAccessoryModeIfNeeded()
      logger.warn("\(componentName) access status unknown raw=\(status.rawValue)")
    }
  }

  /// Updates retry scheduling for one changed authorization state.
  private func handleAuthorizationStateChange(_ status: CLAuthorizationStatus) {
    switch status {
    case .authorized, .authorizedAlways, .authorizedWhenInUse, .denied, .restricted:
      retryBackoff.reset()
      restoreAccessoryModeIfNeeded()

    case .notDetermined:
      scheduleRetry()

    @unknown default:
      retryBackoff.reset()
    }
  }

  /// Schedules one follow-up authorization check while access is unresolved.
  private func scheduleRetry() {
    retryBackoff.schedule { [weak self] in
      self?.requestAccessIfNeeded()
    }
  }

  /// Temporarily prepares the host so macOS can surface the permission prompt.
  private func prepareAuthorizationPromptIfNeeded() {
    guard !presentedAuthorizationPrompt else { return }
    presentedAuthorizationPrompt = true

    logger.info("\(componentName) preparing authorization prompt")
    promptPresenter?.preparePrompt()
  }

  /// Restores host UI after the location permission state resolves.
  private func restoreAccessoryModeIfNeeded() {
    guard presentedAuthorizationPrompt else { return }
    presentedAuthorizationPrompt = false

    logger.info("\(componentName) restoring UI after authorization prompt")
    promptPresenter?.restoreUI()
  }
}
