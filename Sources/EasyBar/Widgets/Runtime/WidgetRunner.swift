import Foundation

final class WidgetRunner {

    static let shared = WidgetRunner()

    private let decoder = JSONDecoder()

    private var requiredEvents = Set<String>()
    private var started = false
    private var runtimeReady = false
    private var subscriptionsReady = false
    private var didEmitInitialEvents = false
    private var stdoutObserver: NSObjectProtocol?

    private init() {}

    /// Starts the widget runtime and begins observing Lua stdout.
    func start() {
        guard !started else {
            Logger.debug("widget runner already started")
            return
        }

        started = true
        runtimeReady = false
        subscriptionsReady = false
        didEmitInitialEvents = false
        requiredEvents.removeAll()

        Logger.debug("starting widget runner")

        stdoutObserver = NotificationCenter.default.addObserver(
            forName: .easyBarLuaStdout,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let line = notification.object as? String else { return }
            self?.handleRuntimeOutput(line)
        }

        LuaRuntime.shared.start()
    }

    /// Reloads the Lua runtime and clears rendered widget state.
    func reload() {
        Logger.debug("reloading widget runner")

        shutdown()
        WidgetStore.shared.clear()
        start()
    }

    /// Stops the widget runtime and related event sources.
    func shutdown() {
        Logger.debug("shutting down widget runner")

        if let stdoutObserver {
            NotificationCenter.default.removeObserver(stdoutObserver)
            self.stdoutObserver = nil
        }

        started = false
        runtimeReady = false
        subscriptionsReady = false
        didEmitInitialEvents = false
        requiredEvents.removeAll()

        EventManager.shared.stopAll()
        LuaRuntime.shared.shutdown()
    }

    /// Handles one line of structured stdout from the Lua runtime.
    private func handleRuntimeOutput(_ line: String) {
        Logger.debug("lua stdout: \(line)")

        guard let data = line.data(using: .utf8) else {
            Logger.warn("invalid utf8: \(line)")
            return
        }

        do {
            let update = try decoder.decode(WidgetTreeUpdate.self, from: data)

            if update.type == "subscriptions" {
                requiredEvents = Set(update.events ?? [])
                subscriptionsReady = true

                Logger.debug("required events: \(requiredEvents)")
                EventManager.shared.start(subscriptions: requiredEvents)
                emitInitialEventsIfPossible()
                return
            }

            if update.type == "ready" {
                Logger.debug("lua runtime handshake received")
                runtimeReady = true
                emitInitialEventsIfPossible()
                return
            }

            if update.type == "tree",
               let root = update.root,
               let nodes = update.nodes {
                Logger.debug("decoded widget tree root=\(root) nodes=\(nodes.count)")
                WidgetStore.shared.apply(root: root, nodes: nodes)
                return
            }

            Logger.warn("unknown lua message: \(line)")
        } catch {
            Logger.warn("json decode failed: \(line)")
            Logger.debug("decode error: \(error)")
        }
    }

    /// Emits initial events after both subscriptions and readiness are known.
    private func emitInitialEventsIfPossible() {
        guard runtimeReady else { return }
        guard subscriptionsReady else { return }
        guard !didEmitInitialEvents else { return }

        didEmitInitialEvents = true
        emitInitialEvents()
    }

    /// Emits initial state-refresh events required by subscribed widgets.
    private func emitInitialEvents() {
        Logger.debug("emitting initial widget events")

        if requiredEvents.contains("system_woke") {
            EventBus.shared.emit(.systemWoke)
        }

        if requiredEvents.contains("power_source_change") {
            EventBus.shared.emit(.powerSourceChange)
        }

        if requiredEvents.contains("charging_state_change") {
            EventBus.shared.emit(.chargingStateChange)
        }

        if requiredEvents.contains("wifi_change") {
            EventBus.shared.emit(.wifiChange)
        }

        if requiredEvents.contains("network_change") {
            EventBus.shared.emit(.networkChange)
        }

        if requiredEvents.contains("volume_change") {
            EventBus.shared.emit(.volumeChange)
        }

        if requiredEvents.contains("mute_change") {
            EventBus.shared.emit(.muteChange)
        }

        if requiredEvents.contains("calendar_change") {
            EventBus.shared.emit(.calendarChange)
        }

        if requiredEvents.contains("minute_tick") {
            EventBus.shared.emit(.minuteTick)
        }

        if requiredEvents.contains("second_tick") {
            EventBus.shared.emit(.secondTick)
        }

        if requiredEvents.contains("focus_change") {
            EventBus.shared.emit(.focusChange)
        }

        if requiredEvents.contains("workspace_change") {
            EventBus.shared.emit(.workspaceChange)
        }

        EventBus.shared.emit(.forced)
    }
}
