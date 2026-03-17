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

    func reload() {
        Logger.debug("reloading widget runner")

        shutdown()
        WidgetStore.shared.clear()
        start()
    }

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

    private func handleRuntimeOutput(_ line: String) {
        Logger.debug("lua stdout: \(line)")

        guard let data = line.data(using: .utf8) else {
            Logger.debug("invalid utf8: \(line)")
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

            Logger.debug("unknown lua message: \(line)")
        } catch {
            Logger.debug("json decode failed: \(line)")
            Logger.debug("decode error: \(error)")
        }
    }

    private func emitInitialEventsIfPossible() {
        guard runtimeReady else { return }
        guard subscriptionsReady else { return }
        guard !didEmitInitialEvents else { return }

        didEmitInitialEvents = true
        emitInitialEvents()
    }

    private func emitInitialEvents() {
        Logger.debug("emitting initial widget events")

        if requiredEvents.contains("system_woke") {
            EventBus.shared.emit("system_woke")
        }

        if requiredEvents.contains("power_source_change") {
            EventBus.shared.emit("power_source_change")
        }

        if requiredEvents.contains("charging_state_change") {
            EventBus.shared.emit("charging_state_change")
        }

        if requiredEvents.contains("wifi_change") {
            EventBus.shared.emit("wifi_change")
        }

        if requiredEvents.contains("network_change") {
            EventBus.shared.emit("network_change")
        }

        if requiredEvents.contains("volume_change") {
            EventBus.shared.emit("volume_change")
        }

        if requiredEvents.contains("mute_change") {
            EventBus.shared.emit("mute_change")
        }

        if requiredEvents.contains("calendar_change") {
            EventBus.shared.emit("calendar_change")
        }

        if requiredEvents.contains("minute_tick") {
            EventBus.shared.emit("minute_tick")
        }

        if requiredEvents.contains("second_tick") {
            EventBus.shared.emit("second_tick")
        }

        if requiredEvents.contains("focus_change") {
            EventBus.shared.emit("focus_change")
        }

        if requiredEvents.contains("workspace_change") {
            EventBus.shared.emit("workspace_change")
        }

        EventBus.shared.emit("forced")
    }
}
