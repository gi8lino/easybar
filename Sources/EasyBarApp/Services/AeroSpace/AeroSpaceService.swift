import AppKit
import EasyBarShared
import Foundation

/// Loads workspace and focused-app state from AeroSpace.
///
/// Widgets can register themselves as consumers so AeroSpace refresh work only
/// runs when at least one native widget depends on that state.
final class AeroSpaceService: ObservableObject {
  /// Published workspace list used by spaces widgets.
  @Published private(set) var spaces: [SpaceItem] = []
  /// Stable id of the focused application.
  @Published private(set) var focusedAppID: String?

  /// Resolved focused app used by `FrontAppNativeWidget`.
  @Published private(set) var focusedApp: SpaceApp?

  /// Resolved layout mode used by `AeroSpaceModeNativeWidget`.
  @Published private(set) var focusedLayoutMode: AeroSpaceLayoutMode = .unknown

  /// Locked service coordination state.
  private struct CoordinationState {
    /// Registered widget consumers.
    var consumers = Set<String>()
    /// Whether the service lifecycle is running.
    var running = false
    /// Whether AeroSpace observation is active for at least one consumer.
    var active = false
    /// Cached AeroSpace version validation result for the current active run.
    var versionRequirementSatisfied: Bool?
    /// Generation used to ignore stale refresh work.
    var generation: UInt64 = 0
  }

  /// Logger used for AeroSpace diagnostics.
  private let logger: ProcessLogger
  /// Runner for AeroSpace CLI commands.
  private let commandRunner: AeroSpaceCommandRunner
  /// Long-lived AeroSpace event subscription.
  private lazy var subscriptionController = AeroSpaceSubscriptionController(
    commandRunner: commandRunner,
    logger: logger.child("subscribe"),
    handleEvent: { [weak self] event in
      self?.handleAeroSpaceSubscriptionEvent(event)
    }
  )
  /// Debounces delayed subscription reloads so event bursts produce one state read.
  private lazy var subscriptionRefreshScheduler = DebouncedActionScheduler(
    label: "aerospace subscription refresh",
    delay: TimeInterval(AeroSpaceSubscriptionEvent.bindingTriggeredRefreshDelayNanoseconds)
      / 1_000_000_000,
    logger: logger
  )
  /// Delayed refresh scheduler used after macOS reports a newly launched app.
  private lazy var launchRefreshScheduler = AeroSpaceLaunchRefreshScheduler(logger: logger)
  /// macOS app lifecycle observer used to complement AeroSpace subscription events.
  private lazy var appObserver = AeroSpaceAppObserver(
    logger: logger.child("app-observer"),
    appActivated: { [weak self] app in
      Task { @MainActor [weak self] in
        self?.applyOptimisticFocusedApp(from: app)
      }
    },
    appLaunched: { [weak self] app in
      self?.scheduleLaunchRefresh(for: app)
    },
    appTerminated: { [weak self] app in
      guard let self else { return }

      self.logger.debug(
        "aerospace observed app termination",
        .field("app", app.localizedName ?? "")
      )
      self.cancelPendingLaunchRefresh(reason: "app terminated")
      self.refresh()
    }
  )
  /// Current locked coordination state.
  private let coordination = LockedState(CoordinationState())

  /// Creates the shared AeroSpace service.
  init(logger: ProcessLogger) {
    self.logger = logger
    self.commandRunner = AeroSpaceCommandRunner(logger: logger.child("commands"))
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
      coordination.versionRequirementSatisfied = nil
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
      coordination.versionRequirementSatisfied = nil
      coordination.generation &+= 1
    }

    logger.debug("aerospace service stop end")
  }

  /// Registers one widget that depends on AeroSpace state.
  func registerConsumer(_ id: String) {
    let count = withLock { coordination -> Int in
      coordination.consumers.insert(id)
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
      coordination.consumers.remove(id)
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
    cancelPendingLaunchRefresh(reason: source)

    guard isActive else {
      logger.debug("aerospace refresh skipped, service inactive or no registered consumers")
      return
    }

    let generation = currentGeneration()

    logger.debug(
      "aerospace triggerRefresh queued",
      .field("source", source),
      .field("consumers", consumerCount)
    )

    DetachedTask.run(priority: .userInitiated) { [weak self] in
      guard let self, self.shouldExecute(generation: generation) else { return }
      self.reloadState(generation: generation)
    }
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

    DetachedTask.run(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: generation) else { return }

      _ = self.runAeroSpace(arguments: ["workspace", workspace])

      guard self.shouldExecute(generation: generation) else { return }
      self.reloadState(generation: generation)
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

  /// Public refresh entry.
  func refresh() {
    guard isActive else {
      logger.debug("aerospace refresh skipped, service inactive or no registered consumers")
      return
    }

    let generation = currentGeneration()

    logger.debug(
      "aerospace refresh queued",
      .field("consumers", consumerCount)
    )

    DetachedTask.run(priority: .userInitiated) { [weak self] in
      guard let self, self.shouldExecute(generation: generation) else { return }
      self.reloadState(generation: generation)
    }
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
      coordination.versionRequirementSatisfied = nil
      coordination.generation &+= 1
      return true
    }

    guard shouldActivate else { return false }

    logger.debug(
      "aerospace service activate begin",
      .field("source", source),
      .field("consumers", consumerCount)
    )

    if ensureAeroSpaceVersionSupported() {
      subscriptionController.start()
    } else {
      logger.debug("aerospace subscription skipped due to unsupported AeroSpace version")
    }

    appObserver.start()
    refresh()

    logger.debug("aerospace service activate end")
    return true
  }

  /// Stops AeroSpace observation once the last consumer disappears.
  fileprivate func deactivateIfNeeded(reason: String) {
    let didDeactivate = withLock { coordination -> Bool in
      guard coordination.active else { return false }

      coordination.active = false
      coordination.versionRequirementSatisfied = nil
      coordination.generation &+= 1

      return true
    }

    guard didDeactivate else { return }

    subscriptionController.stop()
    subscriptionRefreshScheduler.cancel()
    launchRefreshScheduler.cancel(reason: reason)
    appObserver.stop()

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
    let source = EventSourceLabel.aerospaceSubscribe(event.name)
    scheduleSubscriptionRefresh(
      source: source,
      delayNanoseconds: event.refreshDelayNanoseconds
    )

    guard let appEvent = event.appEvent else { return }

    Task {
      await EventHub.shared.emit(appEvent, source: source)
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

    subscriptionRefreshScheduler.schedule { [weak self] in
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

// MARK: - App Observation Handlers

extension AeroSpaceService {
  /// Schedules one delayed refresh for freshly launched apps that may create windows later.
  fileprivate func scheduleLaunchRefresh(for app: NSRunningApplication) {
    logger.debug(
      "aerospace observed app launch",
      .field("app", app.localizedName ?? "")
    )

    launchRefreshScheduler.schedule(
      appName: app.localizedName ?? "",
      generation: currentGeneration(),
      shouldExecute: { [weak self] generation in
        self?.shouldExecute(generation: generation) == true
      },
      refresh: { [weak self] in
        self?.refresh()
      }
    )
  }

  /// Cancels any delayed launch refresh once a stronger signal arrives first.
  fileprivate func cancelPendingLaunchRefresh(reason: String) {
    launchRefreshScheduler.cancel(reason: reason)
  }

  /// Applies an immediate focused-app update from macOS before AeroSpace catches up.
  @MainActor
  fileprivate func applyOptimisticFocusedApp(from app: NSRunningApplication) {
    cancelPendingLaunchRefresh(reason: "app activated")

    let bundlePath = app.bundleURL?.path
    let name = app.localizedName ?? ""
    let id = resolvedAppID(name: name, bundlePath: bundlePath)

    guard !id.isEmpty else { return }

    let focused = SpaceApp(
      id: id,
      bundleID: app.bundleIdentifier ?? "",
      name: name,
      bundlePath: bundlePath
    )

    let didChange = focusedApp != focused || focusedAppID != focused.id
    guard didChange else { return }

    focusedApp = focused
    focusedAppID = focused.id

    logger.debug(
      "aerospace optimistic focus updated",
      .field("app", focused.name)
    )

    NotificationCenter.default.post(name: .easyBarAeroSpaceDidUpdate, object: nil)
  }
}

// MARK: - State Reloading

extension AeroSpaceService {
  /// Reads current AeroSpace state and publishes it.
  fileprivate func reloadState(generation: UInt64) {
    guard shouldExecute(generation: generation) else { return }

    logger.debug("aerospace reloadState begin")

    guard ensureAeroSpaceVersionSupported() else {
      logger.debug("aerospace reloadState skipped due to unsupported AeroSpace version")
      return
    }

    guard shouldExecute(generation: generation) else { return }

    let snapshot = AeroSpaceSnapshotLoader.load(
      run: runAeroSpace(arguments:),
      resolveAppID: resolvedAppID(name:bundlePath:),
      logger: logger
    )

    Task { @MainActor [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: generation) else { return }

      guard self.hasStateChanged(for: snapshot) else {
        self.logger.debug("aerospace reloadState end without changes")
        return
      }

      self.spaces = snapshot.spaces
      self.focusedApp = snapshot.focusedApp
      self.focusedAppID = snapshot.focusedApp?.id
      self.focusedLayoutMode = snapshot.focusedLayoutMode

      self.logger.debug(
        "aerospace state updated",
        .field("spaces", snapshot.spaces.count),
        .field("focused", snapshot.focusedApp?.name ?? "none"),
        .field("layout", snapshot.focusedLayoutMode.rawValue)
      )

      NotificationCenter.default.post(name: .easyBarAeroSpaceDidUpdate, object: nil)

      self.logger.debug("aerospace reloadState end with changes")
    }
  }

  /// Returns whether a freshly loaded snapshot differs from the currently published state.
  @MainActor
  private func hasStateChanged(for snapshot: AeroSpaceSnapshot) -> Bool {
    return spaces != snapshot.spaces
      || focusedApp != snapshot.focusedApp
      || focusedAppID != snapshot.focusedApp?.id
      || focusedLayoutMode != snapshot.focusedLayoutMode
  }
}

// MARK: - AeroSpace Command Execution

extension AeroSpaceService {
  /// Runs the AeroSpace CLI.
  fileprivate func runAeroSpace(arguments: [String]) -> String? {
    guard isActive else { return nil }

    let output = commandRunner.run(arguments: arguments)

    guard isActive else {
      return nil
    }

    return output
  }

  /// Validates the configured AeroSpace version once per active service run.
  fileprivate func ensureAeroSpaceVersionSupported() -> Bool {
    if let cached = withLock({ $0.versionRequirementSatisfied }) {
      return cached
    }

    do {
      try AeroSpaceVersionRequirement.validate(run: commandRunner.run(arguments:))
      withLock { $0.versionRequirementSatisfied = true }
      logger.debug(
        "aerospace version requirement satisfied",
        .field("minimum", AeroSpaceVersionRequirement.minimum.description)
      )
      return true
    } catch {
      withLock { $0.versionRequirementSatisfied = false }
      logger.error(
        "aerospace version requirement failed",
        .field("minimum", AeroSpaceVersionRequirement.minimum.description),
        .field("error", error)
      )
      return false
    }
  }

  /// Resolves a stable app identity from bundle path or name.
  fileprivate func resolvedAppID(name: String, bundlePath: String?) -> String {
    guard let bundlePath, !bundlePath.isEmpty else {
      return name
    }

    return bundlePath
  }

  /// Returns whether the service is still allowed to execute the queued refresh work.
  fileprivate func shouldExecute(generation: UInt64) -> Bool {
    withLock { state in
      state.running && state.active && !state.consumers.isEmpty && state.generation == generation
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

extension Notification.Name {
  /// Notification posted when AeroSpace-derived state changes.
  static let easyBarAeroSpaceDidUpdate = Notification.Name("easybar.aerospace.did-update")
}
