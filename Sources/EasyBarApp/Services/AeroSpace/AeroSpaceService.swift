import AppKit
import EasyBarShared
import Foundation

struct AeroSpaceRefreshToken: Equatable, Sendable {
  let generation: UInt64
  let requestID: UInt64
}

struct AeroSpaceRefreshSequence: Sendable {
  private var latestRequestID: UInt64 = 0

  mutating func issue(generation: UInt64) -> AeroSpaceRefreshToken {
    latestRequestID &+= 1
    return AeroSpaceRefreshToken(generation: generation, requestID: latestRequestID)
  }

  func isCurrent(_ token: AeroSpaceRefreshToken, generation: UInt64) -> Bool {
    token.generation == generation && token.requestID == latestRequestID
  }
}

/// Health of the most recent AeroSpace snapshot attempt.
enum AeroSpaceSnapshotStatus: Equatable, Sendable {
  /// No complete snapshot has been loaded yet.
  case unavailable(message: String)
  /// The published state came from the latest successful refresh.
  case current
  /// Published state is last-known-good because the latest refresh failed.
  case stale(message: String)
}

/// Coalesces concurrent version checks and caches only successful validation.
private actor AeroSpaceVersionValidationCache {
  private struct Attempt {
    let id: UInt64
    let generation: UInt64
    let task: Task<Bool, Never>
  }

  private let commandRunner: any AeroSpaceCommandRunning
  private let logger: ProcessLogger
  private var successfulGeneration: UInt64?
  private var attempt: Attempt?
  private var nextAttemptID: UInt64 = 0

  init(commandRunner: any AeroSpaceCommandRunning, logger: ProcessLogger) {
    self.commandRunner = commandRunner
    self.logger = logger
  }

  func validate(generation: UInt64) async -> Bool {
    if successfulGeneration == generation {
      return true
    }
    if let attempt, attempt.generation == generation {
      return await attempt.task.value
    }

    attempt?.task.cancel()
    nextAttemptID &+= 1
    let attemptID = nextAttemptID
    let commandRunner = commandRunner
    let logger = logger
    let task = Task.detached(priority: .utility) {
      guard let output = await commandRunner.run(arguments: ["--version"]) else {
        logger.debug("aerospace version command unavailable")
        return false
      }

      do {
        try AeroSpaceVersionRequirement.validate(output: output)
        logger.debug(
          "aerospace version requirement satisfied",
          .field("minimum", AeroSpaceVersionRequirement.minimum.description)
        )
        return true
      } catch {
        logger.error(
          "aerospace version requirement failed",
          .field("minimum", AeroSpaceVersionRequirement.minimum.description),
          .field("error", error)
        )
        return false
      }
    }
    attempt = Attempt(id: attemptID, generation: generation, task: task)

    let result = await task.value
    if attempt?.id == attemptID {
      attempt = nil
      if result {
        successfulGeneration = generation
      }
    }
    return result
  }

  func cancel() {
    attempt?.task.cancel()
    attempt = nil
    successfulGeneration = nil
  }
}

/// Loads workspace and focused-app state from AeroSpace.
///
/// Widgets can register themselves as consumers so AeroSpace refresh work only
/// runs when at least one native widget depends on that state.
final class AeroSpaceService: ObservableObject, @unchecked Sendable {
  /// Published workspace list used by spaces widgets.
  @Published private(set) var spaces: [SpaceItem] = []
  /// Resolved focused app used by `FrontAppNativeWidget`.
  @Published private(set) var focusedApp: SpaceApp?

  /// Stable id derived from the canonical focused application state.
  var focusedAppID: String? { focusedApp?.id }

  /// Resolved layout mode used by `AeroSpaceModeNativeWidget`.
  @Published private(set) var focusedLayoutMode: AeroSpaceLayoutMode = .unknown

  /// Whether the published snapshot is current or retained after an error.
  @Published private(set) var snapshotStatus: AeroSpaceSnapshotStatus = .unavailable(
    message: "not loaded"
  )

  /// Locked service coordination state.
  private struct CoordinationState {
    /// Registered widget consumers.
    var consumers: [String: @MainActor @Sendable () -> Void] = [:]
    /// Whether the service lifecycle is running.
    var running = false
    /// Whether AeroSpace observation is active for at least one consumer.
    var active = false
    /// Generation used to ignore stale lifecycle work.
    var generation: UInt64 = 0
    /// Sequence used to ensure only the newest refresh can publish.
    var refreshSequence = AeroSpaceRefreshSequence()
    /// Token reserved for the queued or running refresh.
    var pendingRefreshToken: AeroSpaceRefreshToken?
    /// Cancellable refresh task that owns current CLI commands.
    var refreshTask: Task<Void, Never>?
  }

  /// Logger used for AeroSpace diagnostics.
  private let logger: ProcessLogger
  private let eventHub: EventHub
  /// Runner for AeroSpace CLI commands.
  private let commandRunner: any AeroSpaceCommandRunning
  /// Optional test-provided subscription controller.
  private let subscriptionControllerOverride: (any AeroSpaceSubscriptionControlling)?
  /// Long-lived AeroSpace event subscription.
  private lazy var subscriptionController: any AeroSpaceSubscriptionControlling = {
    if let subscriptionControllerOverride {
      return subscriptionControllerOverride
    }
    return AeroSpaceSubscriptionController(
      logger: logger.child("subscribe"),
      handleEvent: { [weak self] event in
        self?.handleAeroSpaceSubscriptionEvent(event)
      }
    )
  }()
  /// Debounces delayed subscription reloads so event bursts produce one state read.
  private lazy var subscriptionRefreshScheduler = DebouncedActionScheduler(
    label: "aerospace subscription refresh",
    delay: TimeInterval(AeroSpaceSubscriptionEvent.bindingTriggeredRefreshDelayNanoseconds)
      / 1_000_000_000,
    logger: logger
  )
  /// Retries failed version checks and snapshots without requiring another external event.
  private let refreshRetryScheduler: any AeroSpaceReconnectScheduling
  /// Shares one in-flight version check and caches successes per lifecycle generation.
  private let versionValidationCache: AeroSpaceVersionValidationCache
  /// Current locked coordination state.
  private let coordination = LockedState(CoordinationState())

  /// Creates the shared AeroSpace service.
  init(
    logger: ProcessLogger,
    eventHub: EventHub,
    commandRunner: (any AeroSpaceCommandRunning)? = nil,
    subscriptionController: (any AeroSpaceSubscriptionControlling)? = nil,
    refreshRetryScheduler: (any AeroSpaceReconnectScheduling)? = nil
  ) {
    self.logger = logger
    self.eventHub = eventHub
    let resolvedCommandRunner =
      commandRunner ?? AeroSpaceCommandRunner(logger: logger.child("commands"))
    self.commandRunner = resolvedCommandRunner
    self.subscriptionControllerOverride = subscriptionController
    self.refreshRetryScheduler =
      refreshRetryScheduler
      ?? BackoffScheduler(
        label: "aerospace refresh retry",
        delays: [0.5, 1, 2, 5, 10],
        logger: logger,
        logLevel: .debug
      )
    self.versionValidationCache = AeroSpaceVersionValidationCache(
      commandRunner: resolvedCommandRunner,
      logger: logger
    )
  }
}

// MARK: - Public API

extension AeroSpaceService {
  /// Returns whether any native widget currently needs AeroSpace state.
  private var hasConsumers: Bool {
    withLock { !$0.consumers.isEmpty }
  }

  /// Returns whether AeroSpace observation is currently active.
  private var isActive: Bool {
    withLock { $0.running && $0.active && !$0.consumers.isEmpty }
  }

  /// Returns the current registered consumer count.
  private var consumerCount: Int {
    withLock { $0.consumers.count }
  }

  /// Starts the service lifecycle. Expensive observation starts when consumers register.
  func start() {
    let shouldStart = withLock { coordination -> Bool in
      guard !coordination.running else { return false }
      coordination.running = true
      coordination.generation &+= 1
      return true
    }

    guard shouldStart else { return }

    logger.debug("aerospace service start begin")
    if hasConsumers {
      _ = activateIfNeeded(source: "service started")
    }
    logger.debug("aerospace service start end")
  }

  /// Stops the service and prevents queued refresh work from publishing.
  func stop() {
    guard withLock({ $0.running }) else { return }

    deactivateIfNeeded(reason: "service stopped")

    withLock { coordination in
      coordination.running = false
      coordination.consumers.removeAll()
      coordination.generation &+= 1
    }

    logger.debug("aerospace service stop end")
  }

  /// Registers one widget that depends on AeroSpace state.
  func registerConsumer(
    _ id: String,
    onUpdate: @escaping @MainActor @Sendable () -> Void
  ) {
    let count = withLock { coordination -> Int in
      coordination.consumers[id] = onUpdate
      return coordination.consumers.count
    }

    logger.debug(
      "aerospace consumer registered",
      .field("id", id),
      .field("count", count)
    )

    if !activateIfNeeded(source: "consumer registered") {
      refresh()
    }
  }

  /// Unregisters one widget that no longer depends on AeroSpace state.
  func unregisterConsumer(_ id: String) {
    let count = withLock { coordination -> Int in
      coordination.consumers.removeValue(forKey: id)
      return coordination.consumers.count
    }

    logger.debug(
      "aerospace consumer unregistered",
      .field("id", id),
      .field("count", count)
    )

    if count == 0 {
      deactivateIfNeeded(reason: "last consumer unregistered")
    }
  }

  /// Called by the socket server when an external AeroSpace event occurs.
  func triggerRefresh() {
    triggerRefresh(source: "external trigger")
  }

  /// Queues a state reload for one AeroSpace-triggered update source.
  private func triggerRefresh(source: String) {
    guard isActive else {
      logger.debug("aerospace refresh skipped, service inactive or no registered consumers")
      return
    }

    queueRefresh(source: source)
  }

  /// Focuses the requested workspace.
  @MainActor
  func focusWorkspace(_ workspace: String) {
    logger.info(
      "aerospace focus workspace requested",
      .field("workspace", workspace)
    )

    spaces = spaces.map { space in
      SpaceItem(
        id: space.id,
        name: space.name,
        isFocused: space.name == workspace,
        isVisible: space.isVisible,
        apps: space.apps
      )
    }

    let generation = currentGeneration()

    Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: generation) else { return }

      _ = await self.runAeroSpace(arguments: ["workspace", workspace])

      guard self.shouldExecute(generation: generation) else { return }
      self.queueRefresh(source: "workspace focus completed", expectedGeneration: generation)
    }
  }

  /// Activates one application shown inside a workspace.
  @MainActor
  func focusApp(_ app: SpaceApp) {
    logger.info(
      "aerospace focus app requested",
      .field("app", app.name)
    )

    guard let bundlePath = app.bundlePath, !bundlePath.isEmpty else {
      logger.debug(
        "aerospace focus app skipped, missing bundle path",
        .field("app", app.name)
      )
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true

    NSWorkspace.shared.openApplication(
      at: URL(fileURLWithPath: bundlePath),
      configuration: configuration
    ) { [logger] _, error in
      if let error {
        logger.debug(
          "failed to focus app",
          .field("app", app.name),
          .field("error", error)
        )
      }
    }
  }

  /// Returns whether the focused application can currently be hidden.
  @MainActor
  var canHideFocusedApp: Bool {
    guard let app = focusedApp else { return false }
    return runningApplication(for: app) != nil
  }

  /// Returns whether the focused application bundle can be revealed in Finder.
  @MainActor
  var canRevealFocusedApp: Bool {
    guard let path = focusedApp?.bundlePath, !path.isEmpty else { return false }
    return FileManager.default.fileExists(atPath: path)
  }

  /// Hides the application represented by the current AeroSpace snapshot.
  @MainActor
  @discardableResult
  func hideFocusedApp() -> Bool {
    guard let app = focusedApp else {
      logger.warn("cannot hide focused app, AeroSpace has no focused application")
      return false
    }
    guard let runningApplication = runningApplication(for: app) else {
      logger.warn(
        "cannot hide focused app, running application was not resolved",
        .field("app", app.name)
      )
      return false
    }
    guard runningApplication.hide() else {
      logger.warn("failed to hide focused app", .field("app", app.name))
      return false
    }
    logger.debug("hid focused app", .field("app", app.name))
    return true
  }

  /// Reveals the focused application bundle in Finder.
  @MainActor
  @discardableResult
  func revealFocusedAppInFinder() -> Bool {
    guard let app = focusedApp else {
      logger.warn("cannot reveal focused app, AeroSpace has no focused application")
      return false
    }
    guard let path = app.bundlePath, !path.isEmpty else {
      logger.warn("cannot reveal focused app, bundle path is missing", .field("app", app.name))
      return false
    }
    guard FileManager.default.fileExists(atPath: path) else {
      logger.warn(
        "cannot reveal focused app, bundle path does not exist",
        .field("app", app.name),
        .field("path", path)
      )
      return false
    }

    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    logger.debug("revealed focused app in Finder", .field("app", app.name))
    return true
  }

  /// Resolves the running application represented by one AeroSpace app snapshot.
  @MainActor
  private func runningApplication(for app: SpaceApp) -> NSRunningApplication? {
    if !app.bundleID.isEmpty,
      let running = NSWorkspace.shared.runningApplications.first(where: { running in
        running.bundleIdentifier == app.bundleID
      })
    {
      return running
    }

    guard let path = app.bundlePath, !path.isEmpty else { return nil }
    return NSWorkspace.shared.runningApplications.first { running in
      running.bundleURL?.path == path
    }
  }

  /// Changes the focused AeroSpace window/container layout and reloads state.
  func setFocusedLayout(_ mode: AeroSpaceLayoutMode) {
    guard mode != .unknown else {
      logger.warn("ignored unsupported AeroSpace layout request")
      return
    }

    logger.info(
      "aerospace layout requested",
      .field("layout", mode.rawValue)
    )

    let generation = currentGeneration()

    Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: generation) else { return }
      guard await self.runAeroSpace(arguments: AeroSpaceCommandArguments.layout(mode)) != nil else {
        self.logger.warn(
          "failed to change AeroSpace layout",
          .field("layout", mode.rawValue)
        )
        return
      }
      self.logger.debug(
        "changed AeroSpace layout",
        .field("layout", mode.rawValue)
      )
      guard self.shouldExecute(generation: generation) else { return }
      self.queueRefresh(source: "layout change completed", expectedGeneration: generation)
    }
  }

  /// Opens the configuration file currently loaded by AeroSpace.
  func openConfig() {
    let generation = currentGeneration()

    Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: generation) else { return }
      guard
        let path = await self.runAeroSpace(arguments: AeroSpaceCommandArguments.configPath),
        !path.isEmpty
      else {
        self.logger.warn("failed to resolve AeroSpace config path")
        return
      }
      guard FileManager.default.fileExists(atPath: path) else {
        self.logger.warn(
          "AeroSpace config path does not exist",
          .field("path", path)
        )
        return
      }

      Task { @MainActor in
        guard NSWorkspace.shared.open(URL(fileURLWithPath: path)) else {
          self.logger.warn(
            "failed to open AeroSpace config",
            .field("path", path)
          )
          return
        }
        self.logger.debug("opened AeroSpace config", .field("path", path))
      }
    }
  }

  /// Public refresh entry.
  func refresh() {
    guard isActive else {
      logger.debug("aerospace refresh skipped, service inactive or no registered consumers")
      return
    }

    queueRefresh(source: "explicit refresh")
  }
}

// MARK: - Service Activation

extension AeroSpaceService {
  /// Starts expensive AeroSpace observation once the first consumer is present.
  @discardableResult
  fileprivate func activateIfNeeded(source: String) -> Bool {
    let shouldActivate = withLock { coordination -> Bool in
      guard coordination.running, !coordination.active, !coordination.consumers.isEmpty else {
        return false
      }

      coordination.active = true
      coordination.generation &+= 1
      return true
    }

    guard shouldActivate else { return false }

    logger.debug(
      "aerospace service activate begin",
      .field("source", source),
      .field("consumers", consumerCount)
    )

    subscriptionController.start()
    refresh()

    logger.debug("aerospace service activate end")
    return true
  }

  /// Stops AeroSpace observation once the last consumer disappears.
  fileprivate func deactivateIfNeeded(reason: String) {
    let result = withLock { coordination -> (didDeactivate: Bool, task: Task<Void, Never>?) in
      guard coordination.active else { return (false, nil) }

      coordination.active = false
      coordination.generation &+= 1
      coordination.pendingRefreshToken = nil
      let task = coordination.refreshTask
      coordination.refreshTask = nil

      return (true, task)
    }

    guard result.didDeactivate else { return }

    result.task?.cancel()
    subscriptionController.stop()
    subscriptionRefreshScheduler.cancel()
    refreshRetryScheduler.cancel()
    Task { await versionValidationCache.cancel() }

    logger.debug(
      "aerospace service deactivate end",
      .field("reason", reason)
    )
  }
}

// MARK: - AeroSpace Event Subscription

extension AeroSpaceService {
  /// Handles one JSON-line event received from `aerospace subscribe`.
  fileprivate func handleAeroSpaceSubscriptionEvent(_ event: AeroSpaceSubscriptionEvent) {
    let source = "aerospace subscribe \(event.name)"
    scheduleSubscriptionRefresh(
      source: source,
      delayNanoseconds: event.refreshDelayNanoseconds
    )

    guard let appEvent = event.appEvent else { return }

    Task {
      await eventHub.emit(appEvent, source: source)
    }
  }

  /// Refreshes immediately for state-change events and delays only pre-action events.
  fileprivate func scheduleSubscriptionRefresh(source: String, delayNanoseconds: UInt64) {
    let generation = currentGeneration()

    guard delayNanoseconds > 0 else {
      guard shouldExecute(generation: generation) else { return }
      triggerRefresh(source: source)
      logger.debug(
        "aerospace subscription refresh triggered",
        .field("source", source),
        .field("delay_ms", 0)
      )
      return
    }

    let delaySeconds = TimeInterval(delayNanoseconds) / 1_000_000_000
    subscriptionRefreshScheduler.schedule(after: delaySeconds) { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: generation) else { return }
      self.triggerRefresh(source: source)
    }

    logger.debug(
      "aerospace subscription refresh scheduled",
      .field("source", source),
      .field("delay_ms", Int(delayNanoseconds / 1_000_000))
    )
  }
}

// MARK: - State Reloading

extension AeroSpaceService {
  /// Replaces any queued or running refresh with the newest request.
  fileprivate func queueRefresh(source: String, expectedGeneration: UInt64? = nil) {
    let reservation = withLock {
      state -> (token: AeroSpaceRefreshToken, replacedTask: Task<Void, Never>?)? in
      guard state.running, state.active, !state.consumers.isEmpty else { return nil }
      if let expectedGeneration, state.generation != expectedGeneration {
        return nil
      }

      let token = state.refreshSequence.issue(generation: state.generation)
      let replacedTask = state.refreshTask
      state.pendingRefreshToken = token
      state.refreshTask = nil
      return (token, replacedTask)
    }

    guard let reservation else { return }
    reservation.replacedTask?.cancel()

    logger.debug(
      "aerospace refresh queued",
      .field("source", source),
      .field("consumers", consumerCount),
      .field("request_id", reservation.token.requestID)
    )

    let task = Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      await self.reloadState(refreshToken: reservation.token)
    }

    let shouldCancel = withLock { state -> Bool in
      guard state.pendingRefreshToken == reservation.token else { return true }
      state.refreshTask = task
      return false
    }
    if shouldCancel {
      task.cancel()
    }
  }

  /// Reads current AeroSpace state and publishes it, retaining last-known-good state on failure.
  fileprivate func reloadState(refreshToken: AeroSpaceRefreshToken) async {
    defer { finishRefresh(refreshToken) }
    guard shouldExecute(refreshToken: refreshToken), !Task.isCancelled else { return }

    logger.debug(
      "aerospace reloadState begin",
      .field("request_id", refreshToken.requestID)
    )

    guard await versionValidationCache.validate(generation: refreshToken.generation) else {
      guard shouldExecute(refreshToken: refreshToken), !Task.isCancelled else { return }
      await publishRefreshFailure(
        message: "AeroSpace version validation failed",
        refreshToken: refreshToken
      )
      scheduleRefreshRetry(generation: refreshToken.generation)
      return
    }

    guard shouldExecute(refreshToken: refreshToken), !Task.isCancelled else { return }

    do {
      let snapshot = try await AeroSpaceSnapshotLoader.load(
        run: { [weak self] arguments in
          guard let self else { return nil }
          return await self.runAeroSpace(arguments: arguments)
        },
        resolveAppID: { name, bundlePath in
          Self.resolvedAppID(name: name, bundlePath: bundlePath)
        }
      )

      guard shouldExecute(refreshToken: refreshToken), !Task.isCancelled else { return }
      refreshRetryScheduler.cancel()
      await publish(snapshot: snapshot, refreshToken: refreshToken)
    } catch is CancellationError {
      return
    } catch {
      guard shouldExecute(refreshToken: refreshToken), !Task.isCancelled else { return }
      logger.error(
        "aerospace JSON snapshot unavailable",
        .field("error", error),
        .field("request_id", refreshToken.requestID)
      )
      await publishRefreshFailure(
        message: String(describing: error),
        refreshToken: refreshToken
      )
      scheduleRefreshRetry(generation: refreshToken.generation)
    }
  }

  /// Publishes one successful snapshot on the main actor.
  private func publish(
    snapshot: AeroSpaceSnapshot,
    refreshToken: AeroSpaceRefreshToken
  ) async {
    await MainActor.run { [weak self] in
      guard let self, self.shouldExecute(refreshToken: refreshToken) else { return }

      let stateChanged = self.hasStateChanged(for: snapshot)
      let statusChanged = self.snapshotStatus != .current
      self.snapshotStatus = .current

      guard stateChanged || statusChanged else {
        self.logger.debug("aerospace reloadState end without changes")
        return
      }

      self.spaces = snapshot.spaces
      self.focusedApp = snapshot.focusedApp
      self.focusedLayoutMode = snapshot.focusedLayoutMode

      self.logger.debug(
        "aerospace state updated",
        .field("spaces", snapshot.spaces.count),
        .field("focused", snapshot.focusedApp?.name ?? "none"),
        .field("layout", snapshot.focusedLayoutMode.rawValue)
      )

      for callback in self.withLock({ Array($0.consumers.values) }) {
        callback()
      }

      self.logger.debug("aerospace reloadState end with changes")
    }
  }

  /// Marks the snapshot stale or unavailable without clearing published values.
  private func publishRefreshFailure(
    message: String,
    refreshToken: AeroSpaceRefreshToken
  ) async {
    await MainActor.run { [weak self] in
      guard let self, self.shouldExecute(refreshToken: refreshToken) else { return }

      let nextStatus: AeroSpaceSnapshotStatus
      switch self.snapshotStatus {
      case .current, .stale:
        nextStatus = .stale(message: message)
      case .unavailable:
        nextStatus = .unavailable(message: message)
      }

      guard self.snapshotStatus != nextStatus else { return }
      self.snapshotStatus = nextStatus
      for callback in self.withLock({ Array($0.consumers.values) }) {
        callback()
      }
    }
  }

  /// Schedules another refresh after a transient validation or snapshot failure.
  private func scheduleRefreshRetry(generation: UInt64) {
    guard shouldExecute(generation: generation) else { return }
    refreshRetryScheduler.schedule { [weak self] in
      self?.queueRefresh(source: "failure retry", expectedGeneration: generation)
    }
  }

  /// Clears task ownership only when the completed task is still current.
  private func finishRefresh(_ refreshToken: AeroSpaceRefreshToken) {
    withLock { state in
      guard state.pendingRefreshToken == refreshToken else { return }
      state.pendingRefreshToken = nil
      state.refreshTask = nil
    }
  }

  /// Returns whether a freshly loaded snapshot differs from the currently published state.
  @MainActor
  private func hasStateChanged(for snapshot: AeroSpaceSnapshot) -> Bool {
    spaces != snapshot.spaces
      || focusedApp != snapshot.focusedApp
      || focusedLayoutMode != snapshot.focusedLayoutMode
  }
}

// MARK: - AeroSpace Command Execution

extension AeroSpaceService {
  /// Runs the AeroSpace CLI while the service lifecycle remains active.
  fileprivate func runAeroSpace(arguments: [String]) async -> String? {
    guard isActive, !Task.isCancelled else { return nil }

    let output = await commandRunner.run(arguments: arguments)

    guard isActive, !Task.isCancelled else { return nil }
    return output
  }

  /// Resolves a stable app identity from bundle path or name.
  fileprivate static func resolvedAppID(name: String, bundlePath: String?) -> String {
    guard let bundlePath, !bundlePath.isEmpty else {
      return name
    }

    return bundlePath
  }

  /// Returns whether the service is still allowed to execute queued work.
  fileprivate func shouldExecute(generation: UInt64) -> Bool {
    withLock { state in
      state.running && state.active && !state.consumers.isEmpty && state.generation == generation
    }
  }

  /// Returns whether this token is still the newest refresh in the active lifecycle.
  fileprivate func shouldExecute(refreshToken: AeroSpaceRefreshToken) -> Bool {
    withLock { state in
      state.running
        && state.active
        && !state.consumers.isEmpty
        && state.pendingRefreshToken == refreshToken
        && state.refreshSequence.isCurrent(refreshToken, generation: state.generation)
    }
  }

  /// Returns the current refresh generation.
  fileprivate func currentGeneration() -> UInt64 {
    withLock { $0.generation }
  }

  /// Runs one closure while holding the service state lock.
  private func withLock<T>(_ body: @Sendable (inout CoordinationState) -> T) -> T {
    coordination.withLock(body)
  }
}
