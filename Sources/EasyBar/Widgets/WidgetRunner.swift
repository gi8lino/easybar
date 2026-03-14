import Foundation

final class WidgetRunner {

    static let shared = WidgetRunner()

    private let decoder = JSONDecoder()

    private var requiredEvents = Set<String>()
    private var started = false
    private var stdoutObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard !started else {
            Logger.debug("widget runner already started")
            return
        }

        started = true

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
        evaluateSubscriptions()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.emitInitialEvents()
        }
    }

    func reload() {
        Logger.debug("reloading widget runner")

        shutdown()
        WidgetStore.shared.clear()

        requiredEvents.removeAll()
        started = false

        start()
    }

    func shutdown() {
        Logger.debug("shutting down widget runner")

        if let stdoutObserver {
            NotificationCenter.default.removeObserver(stdoutObserver)
            self.stdoutObserver = nil
        }

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

            if update.type == "ready" {
                Logger.debug("lua runtime handshake received")
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
        }
    }

    private func evaluateSubscriptions() {
        Logger.debug("evaluating widget subscriptions")

        let widgetPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/easybar/widgets")
            .path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Config.shared.luaPath)
        process.arguments = [
            "-e",
            """
            local dir="\(widgetPath)"
            for f in io.popen('ls "'..dir..'" 2>/dev/null'):lines() do
                if f:match("%.lua$") then
                    local ok, w = pcall(dofile, dir.."/"..f)
                    if ok and type(w) == "table" and w.subscribe then
                        for _,e in ipairs(w.subscribe) do
                            print(e)
                        end
                    end
                end
            end
            """
        ]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            Logger.debug("subscription scan failed")
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        guard let output = String(data: data, encoding: .utf8) else { return }

        output.split(separator: "\n").forEach {
            requiredEvents.insert(String($0))
        }

        Logger.debug("required events: \(requiredEvents)")
        EventManager.shared.start(subscriptions: requiredEvents)
    }

    private func emitInitialEvents() {
        Logger.debug("emitting initial widget events")

        if requiredEvents.contains("system_woke") {
            EventBus.shared.emit("system_woke")
        }

        if requiredEvents.contains("power_source_change") {
            EventBus.shared.emit("power_source_change")
        }

        if requiredEvents.contains("wifi_change") {
            EventBus.shared.emit("wifi_change")
        }

        if requiredEvents.contains("network_change") {
            EventBus.shared.emit("network_change")
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
    }
}
