import AppKit
import EasyBarShared
import Foundation

/// Loads workspace and focused-app state from AeroSpace.
///
/// Widgets can register themselves as consumers so AeroSpace refresh work only
/// runs when at least one native widget depends on that state.
final class AeroSpaceService: ObservableObject {
  private static var sharedInstance: AeroSpaceService?

  /// Returns the configured shared AeroSpace service.
  static var shared: AeroSpaceService {
    guard let sharedInstance else {
      fatalError(
        "AeroSpaceService.bootstrap(logger:) must be called before AeroSpaceService.shared")
    }

    return sharedInstance
  }

  /// Configures the shared AeroSpace service.
  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = AeroSpaceService(logger: logger)
  }

  @Published private(set) var spaces: [SpaceItem] = []
  @Published private(set) var focusedAppID: String?

  /// Resolved focused app used by `FrontAppNativeWidget`.
  @Published private(set) var focusedApp: SpaceApp?

  /// Resolved layout mode used by `AeroSpaceModeNativeWidget`.
  @Published private(set) var focusedLayoutMode: AeroSpaceLayoutMode = .unknown

  private struct CoordinationState {
    var consumers = Set<String>()
    var appSwitchObserver: NSObjectProtocol?
    var running = false
    var generation: UInt64 = 0
  }

  private let logger: ProcessLogger
  private let refreshQueue = DispatchQueue(label: "easybar.aerospace.refresh", qos: .userInitiated)
  private let commandRunner: AeroSpaceCommandRunner
  private let stateLock = NSLock()
  private var coordination = CoordinationState()

  private init(logger: ProcessLogger) {
    self.logger = logger
    self.commandRunner = AeroSpaceCommandRunner(logger: logger.child("commands"))
  }
}

// MARK: - Public API

extension AeroSpaceService {
  /// Returns whether any native widget currently needs AeroSpace state.
  private var hasConsumers: Bool {
    withLock { !coordination.consumers.isEmpty }
  }

  /// Returns the current registered consumer count.
  private var consumerCount: Int {
    withLock { coordination.consumers.count }
  }

  /// Starts the service.
  func start() {
    let shouldStart = withLock { () -> Bool in
      guard !coordination.running else { return false }
      coordination.running = true
      coordination.generation &+= 1
      return true
    }

    guard shouldStart else { return }

    logger.debug("aerospace service start begin")
    subscribeAppSwitches()
    refresh()
    logger.debug("aerospace service start end")
  }

  /// Stops the service and prevents queued refresh work from publishing.
  func stop() {
    let observer = withLock { () -> NSObjectProtocol? in
      guard coordination.running else { return nil }
      coordination.running = false
      coordination.generation &+= 1
      let observer = coordination.appSwitchObserver
      coordination.appSwitchObserver = nil
      return observer
    }

    if let observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }

    logger.debug("aerospace service stop end")
  }

  /// Registers one widget that depends on AeroSpace state.
  func registerConsumer(_ id: String) {
    let count = withLock { () -> Int in
      coordination.consumers.insert(id)
      return coordination.consumers.count
    }

    logger.debug("aerospace consumer registered", "id", id, "count", count)
    refresh()
  }

  /// Unregisters one widget that no longer depends on AeroSpace state.
  func unregisterConsumer(_ id: String) {
    let count = withLock { () -> Int in
      coordination.consumers.remove(id)
      return coordination.consumers.count
    }

    logger.debug("aerospace consumer unregistered", "id", id, "count", count)
  }

  /// Called by the socket server when an external AeroSpace event occurs.
  func triggerRefresh() {
    guard hasConsumers else {
      logger.debug("aerospace refresh skipped, no registered consumers")
      return
    }

    let generation = currentGeneration()
    logger.debug("aerospace triggerRefresh queued", "consumers", consumerCount)

    refreshQueue.async { [weak self] in
      guard let self, self.shouldExecute(generation: generation) else { return }
      self.reloadState()
    }
  }

  /// Focuses the requested workspace.
  func focusWorkspace(_ workspace: String) {
    logger.info("aerospace focus workspace requested", "workspace", workspace)

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      self.spaces = self.spaces.map { space in
        SpaceItem(
          id: space.id,
          name: space.name,
          isFocused: space.name == workspace,
          isVisible: space.isVisible,
          apps: space.apps
        )
      }
    }

    refreshQueue.async { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: self.currentGeneration()) else { return }
      _ = self.runAeroSpace(arguments: ["workspace", workspace])
      guard self.shouldExecute(generation: self.currentGeneration()) else { return }
      self.reloadState()
    }
  }

  /// Activates one application shown inside a workspace.
  func focusApp(_ app: SpaceApp) {
    logger.info("aerospace focus app requested", "app", app.name)

    guard let bundlePath = app.bundlePath, !bundlePath.isEmpty else {
      logger.debug("aerospace focus app skipped, missing bundle path", "app", app.name)
      return
    }

    DispatchQueue.main.async { [logger] in
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true

      NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: bundlePath),
        configuration: configuration
      ) { _, error in
        if let error {
          logger.debug("failed to focus app", "app", app.name, "error", error)
        }
      }
    }
  }

  /// Public refresh entry.
  func refresh() {
    guard hasConsumers else {
      logger.debug("aerospace refresh skipped, no registered consumers")
      return
    }

    let generation = currentGeneration()
    logger.debug("aerospace refresh queued", "consumers", consumerCount)

    refreshQueue.async { [weak self] in
      guard let self, self.shouldExecute(generation: generation) else { return }
      self.reloadState()
    }
  }
}

// MARK: - App Switch Observation

extension AeroSpaceService {
  /// Listens for app activation so focused-app UI can update immediately.
  fileprivate func subscribeAppSwitches() {
    let shouldInstall = withLock { coordination.appSwitchObserver == nil }
    guard shouldInstall else { return }

    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
      else {
        return
      }

      self.applyOptimisticFocusedApp(from: app)
    }

    withLock {
      if coordination.appSwitchObserver == nil {
        coordination.appSwitchObserver = observer
      }
    }

    logger.debug("aerospace app switch observer installed")
  }

  /// Applies an immediate focused-app update from macOS before AeroSpace catches up.
  fileprivate func applyOptimisticFocusedApp(from app: NSRunningApplication) {
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

    publishUpdate(logMessage: "aerospace optimistic focus updated", fields: ["app": focused.name])
  }
}

// MARK: - State Reloading

extension AeroSpaceService {
  /// Reads current AeroSpace state and publishes it.
  fileprivate func reloadState() {
    guard shouldExecute(generation: currentGeneration()) else { return }
    logger.debug("aerospace reloadState begin")

    let snapshot = AeroSpaceSnapshotLoader.load(
      run: runAeroSpace(arguments:),
      resolveAppID: resolvedAppID(name:bundlePath:)
    )

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: self.currentGeneration()) else { return }

      let spacesChanged = self.spaces != snapshot.spaces
      let focusedAppChanged = self.focusedApp != snapshot.focusedApp
      let focusedAppIDChanged = self.focusedAppID != snapshot.focusedApp?.id
      let layoutChanged = self.focusedLayoutMode != snapshot.focusedLayoutMode

      guard spacesChanged || focusedAppChanged || focusedAppIDChanged || layoutChanged else {
        self.logger.debug("aerospace reloadState end without changes")
        return
      }

      self.spaces = snapshot.spaces
      self.focusedApp = snapshot.focusedApp
      self.focusedAppID = snapshot.focusedApp?.id
      self.focusedLayoutMode = snapshot.focusedLayoutMode

      self.publishUpdate(
        logMessage: "aerospace state updated",
        fields: [
          "spaces": snapshot.spaces.count,
          "focused": snapshot.focusedApp?.name ?? "none",
          "layout": snapshot.focusedLayoutMode.rawValue,
        ]
      )

      self.logger.debug("aerospace reloadState end with changes")
    }
  }
}

// MARK: - AeroSpace Command Execution

extension AeroSpaceService {
  /// Runs the AeroSpace CLI.
  fileprivate func runAeroSpace(arguments: [String]) -> String? {
    guard isRunning else { return nil }

    let output = commandRunner.run(arguments: arguments)
    guard isRunning else {
      return nil
    }

    return output
  }

  /// Resolves a stable app identity from bundle path or name.
  fileprivate func resolvedAppID(name: String, bundlePath: String?) -> String {
    guard let bundlePath, !bundlePath.isEmpty else {
      return name
    }

    return bundlePath
  }

  /// Publishes one shared AeroSpace update notification.
  fileprivate func publishUpdate(logMessage: String, fields: [String: Any] = [:]) {
    var components: [Any] = []
    for key in fields.keys.sorted() {
      components.append(key)
      components.append(fields[key] ?? "nil")
    }

    logger.debug(logMessage, components)
    NotificationCenter.default.post(name: .easyBarAeroSpaceDidUpdate, object: nil)
  }

  /// Returns whether the service is still allowed to execute the queued refresh work.
  fileprivate func shouldExecute(generation: UInt64) -> Bool {
    withLock {
      coordination.running && coordination.generation == generation
    }
  }

  /// Returns the current refresh generation.
  fileprivate func currentGeneration() -> UInt64 {
    withLock { coordination.generation }
  }

  /// Returns whether the service is currently running.
  fileprivate var isRunning: Bool {
    withLock { coordination.running }
  }

  /// Runs one closure while holding the service state lock.
  fileprivate func withLock<T>(_ body: () -> T) -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return body()
  }
}

extension Notification.Name {
  static let easyBarAeroSpaceDidUpdate = Notification.Name("easybar.aerospace.did-update")
}
