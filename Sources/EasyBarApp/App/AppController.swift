import AppKit
import EasyBarShared
import Foundation

/// Main-actor app shell responsible for UI lifecycle and startup wiring.
@MainActor
final class AppController {
  /// Logger used for app-shell diagnostics.
  private let logger: ProcessLogger
  /// Explicit app-wide service graph bootstrapped during startup wiring.
  private let services: AppServices
  /// Coordinates runtime startup, refresh, reload, and shutdown.
  private let runtimeCoordinator: RuntimeCoordinator
  /// Callback used to ask the app delegate to start graceful termination.
  private let requestAppTermination: () -> Void
  /// Logs one-time startup diagnostics for support and troubleshooting.
  private let startupDiagnostics: AppStartupDiagnostics
  /// Installs the generated Lua editor stub for widget authoring.
  private let widgetEditorStubInstaller: WidgetEditorStubInstaller
  /// Converts process signals into graceful termination requests.
  private lazy var signalHandler = AppSignalHandler(logger: logger.child("signals")) {
    [weak self] in
    self?.requestAppTermination()
  }

  /// Whether the app shell has completed startup.
  private var started = false
  /// Shared shutdown task used to avoid duplicate cleanup.
  private var shutdownTask: Task<Void, Never>?
  /// Task that waits for graceful shutdown before terminating AppKit.
  private var terminationRequestTask: Task<Void, Never>?
  /// Controller for the main EasyBar panel.
  private var barWindowController: BarWindowController?
  /// Persistent controller shown in the macOS menu bar.
  private var menuBarController: MenuBarController?
  /// Whether the bar runtime is currently available to user actions.
  private var barRuntimeState = MenuBarController.RuntimeState.stopped
  /// Serializes user-requested start, stop, and restart transitions.
  private var barLifecycleTask: Task<Void, Never>?
  /// Observer token for runtime config reload completion notifications.
  private var configReloadObserver: NSObjectProtocol?

  /// Presenter for config load and reload errors.
  private let configErrorWindowController = ConfigErrorWindowController()
  /// Prevents multiple EasyBar instances from running at once.
  private let instanceGuard = SingleInstanceGuard()

  /// Creates the app shell with its process logger.
  init(
    logger: ProcessLogger,
    requestAppTermination: @escaping () -> Void
  ) {
    self.logger = logger
    self.requestAppTermination = requestAppTermination
    self.services = Self.bootstrapSharedDependencies(logger: logger.child("services"))
    self.runtimeCoordinator = RuntimeCoordinator(
      logger: logger.child("runtime"),
      services: services
    )
    self.startupDiagnostics = AppStartupDiagnostics(logger: logger.child("diagnostics"))
    self.widgetEditorStubInstaller = WidgetEditorStubInstaller(logger: logger.child("editor_stub"))
  }

  /// Starts the app shell and the actor-owned runtime.
  @discardableResult
  func start() -> Bool {
    guard !started else {
      logger.debug("AppController.start skipped because app is already started")
      return true
    }

    started = true

    let initialConfigError = services.config.loadInitialState()
    configureLogging()
    logger.debug("process logging configured")

    if let error = initialConfigError {
      logger.error(
        "initial config load failed",
        .field("config_path", services.config.configPath),
        .field("error", "\(error)")
      )
    } else {
      logger.info(
        "initial config loaded",
        .field("config_path", services.config.configPath)
      )
    }

    logger.debug("applying runtime configuration")
    services.applyRuntimeConfiguration(services.config.snapshot())

    guard acquireInstanceLock() else {
      started = false
      return false
    }

    NSApp.setActivationPolicy(.accessory)
    logger.debug("activation policy set to accessory")

    startupDiagnostics.logStartup(services: services)
    startupDiagnostics.validateRequiredFonts()
    installWidgetEditorStub()

    let menuStateProvider = makeMenuStateProvider()
    setupBarWindowController(menuStateProvider: menuStateProvider)
    setupMenuBarController(stateProvider: menuStateProvider)
    logger.debug("bar window presented")

    installConfigReloadObserver()
    updateConfigErrorWindow()
    signalHandler.start()
    logger.debug("signal handler started")

    barRuntimeState = .transitioning
    Task {
      await runtimeCoordinator.start()
      await MainActor.run { [weak self] in
        self?.barRuntimeState = .running
      }
    }
    logger.debug("runtime coordinator start scheduled")

    return true
  }

  /// Acquires the single-instance lock for the main EasyBar process.
  private func acquireInstanceLock() -> Bool {
    AppShellSupport.acquireInstanceLock(
      instanceGuard: instanceGuard,
      processName: "easybar",
      directory: services.config.lockDirectory,
      logger: logger,
      acquireMessage: "easybar acquired instance lock",
      alreadyRunningMessage: "easybar already running",
      failureMessage: "easybar failed to acquire instance lock",
    )
  }

  /// Stops the actor-owned runtime.
  func stop() {
    _ = ensureShutdownTask()
  }

  /// Stops the actor-owned runtime and waits for cleanup to finish.
  func stopAndWait() async {
    guard let shutdownTask = ensureShutdownTask() else { return }

    await shutdownTask.value
    self.shutdownTask = nil
  }

  /// Requests graceful shutdown, then calls the completion once cleanup is complete.
  func requestTermination(completion: @escaping @MainActor () -> Void) {
    guard terminationRequestTask == nil else { return }

    terminationRequestTask = Task { [weak self] in
      guard let self else { return }

      await self.completeTerminationRequest(completion: completion)
    }
  }

  /// Completes graceful shutdown before handing control back to AppKit termination.
  private func completeTerminationRequest(completion: @escaping @MainActor () -> Void) async {
    await stopAndWait()

    await MainActor.run {
      terminationRequestTask = nil
      completion()
    }
  }

  /// Applies all UI-side work required after a config reload.
  func handlePostConfigReloadUI() {
    installWidgetEditorStub()
    barWindowController?.reloadLayout()
    menuBarController?.setVisible(services.configSnapshotStore.snapshot.app.showMenuBarIcon)
    updateConfigErrorWindow()
  }

  /// Observes runtime config reload completion so UI stays in sync.
  private func installConfigReloadObserver() {
    guard configReloadObserver == nil else { return }

    configReloadObserver = NotificationCenter.default.addObserver(
      forName: .easyBarConfigReloadDidFinish,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.handlePostConfigReloadUI()
      }
    }
  }

  /// Keeps the config error window in sync with the current config state.
  func updateConfigErrorWindow() {
    guard let failureState = services.config.loadFailureState else {
      configErrorWindowController.close()
      return
    }

    configErrorWindowController.present(
      failureState: failureState,
      configPath: services.config.configPath,
      onReload: { [weak self] in
        guard let self else { return }

        Task {
          await self.runtimeCoordinator.reloadConfig()
        }
      }
    )
  }

  /// Bootstraps all shared logger-owning services before runtime startup begins.
  private static func bootstrapSharedDependencies(logger: ProcessLogger) -> AppServices {
    AppServices.bootstrap(logger: logger)
  }

  /// Configures file logging from the current app config.
  private func configureLogging() {
    AppShellSupport.configureLogging(
      logger: logger,
      minimumLevel: services.config.loggingLevel,
      fileLoggingEnabled: services.config.loggingEnabled,
      loggingDirectory: services.config.loggingDirectory,
      logFileName: "easybar.out"
    )
  }

  /// Creates and presents the main bar window controller.
  private func setupBarWindowController(menuStateProvider: BarContextMenuStateProviding) {
    let controller = BarWindowController(
      logger: logger.child("window"),
      configStore: services.configSnapshotStore,
      widgetStore: services.widgetStore,
      aeroSpaceService: services.aeroSpaceService,
      menuStateProvider: menuStateProvider
    )
    installBarWindowActions(on: controller)
    controller.present()
    barWindowController = controller
  }

  private func makeMenuStateProvider() -> BarContextMenuStateProvider {
    BarContextMenuStateProvider(
      nativeWiFiStore: services.nativeWiFiStore,
      nativeMonthCalendarStore: services.nativeMonthCalendarStore,
      nativeUpcomingCalendarStore: services.nativeUpcomingCalendarStore,
      monthCalendarAgentClient: services.monthCalendarAgentClient,
      upcomingCalendarAgentClient: services.upcomingCalendarAgentClient,
      networkAgentClient: services.networkAgentClient
    )
  }

  /// Creates the controller icon that survives bar-runtime shutdown.
  private func setupMenuBarController(stateProvider: BarContextMenuStateProviding) {
    let controller = MenuBarController(
      configStore: services.configSnapshotStore,
      stateProvider: stateProvider
    )
    controller.runtimeState = { [weak self] in self?.barRuntimeState ?? .stopped }
    controller.onStart = { [weak self] in self?.startBar() }
    controller.onStop = { [weak self] in self?.stopBar() }
    controller.onRestart = { [weak self] in self?.restartBar() }
    controller.onRefresh = { [weak self] in self?.refreshRuntime() }
    controller.onReloadConfig = { [weak self] in self?.reloadConfig() }
    controller.onRestartLuaRuntime = { [weak self] in self?.restartLuaRuntime() }
    controller.onRestartCalendarAgent = { [weak self] in self?.restartCalendarAgent() }
    controller.onRestartNetworkAgent = { [weak self] in self?.restartNetworkAgent() }
    controller.onSelectTheme = { [weak self] name in self?.selectTheme(name) }
    controller.onQuit = { [weak self] in self?.requestAppTermination() }
    controller.setVisible(services.configSnapshotStore.snapshot.app.showMenuBarIcon)
    menuBarController = controller
  }

  private func startBar() {
    runBarLifecycleTransition(finalState: .running) { [weak self] in
      guard let self else { return }
      await self.runtimeCoordinator.start()
      await MainActor.run { self.barWindowController?.present() }
    }
  }

  private func stopBar() {
    barWindowController?.hide()
    runBarLifecycleTransition(finalState: .stopped) { [weak self] in
      await self?.runtimeCoordinator.stop()
    }
  }

  private func restartBar() {
    barWindowController?.hide()
    runBarLifecycleTransition(finalState: .running) { [weak self] in
      guard let self else { return }
      await self.runtimeCoordinator.stop()
      await self.runtimeCoordinator.start()
      await MainActor.run { self.barWindowController?.present() }
    }
  }

  private func runBarLifecycleTransition(
    finalState: MenuBarController.RuntimeState,
    operation: @escaping @MainActor () async -> Void
  ) {
    guard barLifecycleTask == nil else { return }
    barRuntimeState = .transitioning
    barLifecycleTask = Task { [weak self] in
      await operation()
      guard let self else { return }
      self.barRuntimeState = finalState
      self.barLifecycleTask = nil
    }
  }

  private func refreshRuntime() {
    Task { await runtimeCoordinator.refreshRuntime() }
  }

  private func reloadConfig() {
    Task { await runtimeCoordinator.reloadConfig() }
  }

  private func restartLuaRuntime() {
    Task { await runtimeCoordinator.restartLuaRuntime() }
  }

  private func selectTheme(_ name: String?) {
    Task { await runtimeCoordinator.applyThemeOverride(name) }
  }

  private func restartCalendarAgent() {
    let socketPath = services.configSnapshotStore.snapshot.calendarAgent.socketPath
    Task.detached { [logger] in
      do {
        try AgentRestartClient.restartCalendarAgent(socketPath: socketPath)
        logger.info("calendar agent restart acknowledged")
      } catch {
        logger.error("calendar agent restart failed", .field("error", "\(error)"))
      }
    }
  }

  private func restartNetworkAgent() {
    let socketPath = services.configSnapshotStore.snapshot.networkAgent.socketPath
    Task.detached { [logger] in
      do {
        try AgentRestartClient.restartNetworkAgent(socketPath: socketPath)
        logger.info("network agent restart acknowledged")
      } catch {
        logger.error("network agent restart failed", .field("error", "\(error)"))
      }
    }
  }

  /// Wires user-facing bar actions to runtime commands.
  private func installBarWindowActions(on controller: BarWindowController) {
    controller.onRefresh = { [weak self] in
      guard let self else { return }

      Task {
        await self.runtimeCoordinator.refreshRuntime()
      }
    }

    controller.onReloadConfig = { [weak self] in
      guard let self else { return }

      Task {
        await self.runtimeCoordinator.reloadConfig()
      }
    }

    controller.onRestartLuaRuntime = { [weak self] in
      guard let self else { return }

      Task {
        await self.runtimeCoordinator.restartLuaRuntime()
      }
    }

    controller.onSelectTheme = { [weak self] name in
      self?.selectTheme(name)
    }
  }

  /// Installs the bundled Lua editor stub into the configured editor-stub path.
  private func installWidgetEditorStub() {
    widgetEditorStubInstaller.install(stubPath: services.config.widgetEditorStubPath)
  }

  /// Starts one shared shutdown task when the app is still running.
  private func ensureShutdownTask() -> Task<Void, Never>? {
    if let shutdownTask {
      return shutdownTask
    }

    guard started else { return nil }
    started = false
    barRuntimeState = .transitioning

    logger.info("easybar shutting down")
    signalHandler.stop()
    let pendingBarLifecycleTask = barLifecycleTask
    let shutdownTask = Task { [runtimeCoordinator] in
      await pendingBarLifecycleTask?.value
      await runtimeCoordinator.stop()
    }

    self.shutdownTask = shutdownTask
    return shutdownTask
  }
}
