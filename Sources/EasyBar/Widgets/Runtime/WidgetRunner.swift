import Foundation

final class WidgetRunner {

    static let shared = WidgetRunner()

    private let decoder = JSONDecoder()
    private let subscriptionQueue = DispatchQueue(
        label: "easybar.widgetrunner.subscriptions",
        qos: .userInitiated
    )

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

        // Start the long-running runtime first.
        LuaRuntime.shared.start()

        // Discover event subscriptions in parallel.
        evaluateSubscriptions()
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

    private func evaluateSubscriptions() {
        let widgetPath = Config.shared.widgetsPath
        let luaPath = Config.shared.luaPath

        Logger.debug("evaluating widget subscriptions from \(widgetPath)")

        subscriptionQueue.async { [weak self] in
            guard let self else { return }

            let discovered = self.scanSubscriptions(
                widgetPath: widgetPath,
                luaPath: luaPath
            )

            DispatchQueue.main.async {
                guard self.started else { return }

                self.requiredEvents = discovered
                self.subscriptionsReady = true

                Logger.debug("required events: \(self.requiredEvents)")
                EventManager.shared.start(subscriptions: self.requiredEvents)

                self.emitInitialEventsIfPossible()
            }
        }
    }

    private func scanSubscriptions(widgetPath: String, luaPath: String) -> Set<String> {
        var result = Set<String>()

        let widgetDirectoryURL = URL(fileURLWithPath: widgetPath)

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: widgetDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            Logger.debug("failed to enumerate widget directory")
            return result
        }

        let widgetFiles = files
            .filter { $0.pathExtension == "lua" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        if widgetFiles.isEmpty {
            Logger.debug("no lua widgets found")
            return result
        }

        for fileURL in widgetFiles {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: luaPath)

            // Use an environment variable instead of arg[1].
            // This avoids the fragile indexing behavior of `lua -e`.
            process.arguments = [
                "-e",
                """
                local path = os.getenv("EASYBAR_WIDGET_FILE")
                if not path or path == "" then
                    os.exit(1)
                end

                local ok, widget = pcall(dofile, path)
                if ok and type(widget) == "table" and type(widget.subscribe) == "table" then
                    for _, event in ipairs(widget.subscribe) do
                        print(event)
                    end
                end
                """
            ]

            var environment = ProcessInfo.processInfo.environment
            environment["EASYBAR_WIDGET_FILE"] = fileURL.path
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                Logger.debug(
                    "subscription scan failed for \(fileURL.lastPathComponent): \(error)"
                )
                continue
            }

            process.waitUntilExit()

            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            if let stderr = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !stderr.isEmpty {
                Logger.debug(
                    "subscription scan stderr for \(fileURL.lastPathComponent): \(stderr)"
                )
            }

            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                Logger.debug(
                    "subscription scan produced non-utf8 output for \(fileURL.lastPathComponent)"
                )
                continue
            }

            let events = output
                .split(whereSeparator: \.isNewline)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if events.isEmpty {
                Logger.debug(
                    "no subscriptions found for \(fileURL.lastPathComponent)"
                )
            } else {
                Logger.debug(
                    "subscriptions for \(fileURL.lastPathComponent): \(events)"
                )
            }

            for event in events {
                result.insert(event)
            }
        }

        return result
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
    }
}
