import Foundation

/// Tracks the process group ID of the running Lua runtime process.
/// This lets EasyBar terminate the runtime and any child processes it spawned.
private var easyBarLuaProcessGroupPID: pid_t = 0

/// Terminates the Lua runtime process group.
///
/// A soft terminate is attempted first, then a forced kill shortly after.
/// This prevents orphaned child processes from surviving reload/shutdown.
private func easyBarTerminateLuaProcessGroup() {
    let pid = easyBarLuaProcessGroupPID
    guard pid > 0 else { return }

    kill(-pid, SIGTERM)
    usleep(150_000)
    kill(-pid, SIGKILL)

    easyBarLuaProcessGroupPID = 0
}

/// Handles termination-related signals by shutting down the Lua process group first.
private func easyBarSignalHandler(_ signal: Int32) {
    easyBarTerminateLuaProcessGroup()
    Darwin.signal(signal, SIG_DFL)
    Darwin.raise(signal)
}

/// Manages the long-running Lua runtime process used for scripted widgets.
///
/// stdout is reserved for structured JSON widget updates.
/// stderr is used for structured Lua/widget logs and runtime errors.
final class LuaRuntime {

    static let shared = LuaRuntime()

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    // Serialize writes so events do not interleave on stdin.
    private let writeQueue = DispatchQueue(label: "easybar.lua.write")
    private var signalHandlersInstalled = false

    private init() {}

    /// Starts the Lua runtime if it is not already running.
    func start() {
        guard process == nil else {
            Logger.debug("lua runtime already started")
            return
        }

        installSignalHandlersIfNeeded()

        guard let runtime = Bundle.module.url(forResource: "runtime", withExtension: "lua") else {
            Logger.error("runtime.lua not found")
            return
        }

        Logger.debug("starting lua runtime")
        Logger.debug("lua binary: \(Config.shared.luaPath)")
        Logger.debug("lua script: \(runtime.path)")
        Logger.debug("widgets path: \(Config.shared.widgetsPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Config.shared.luaPath)
        process.arguments = [runtime.path, Config.shared.widgetsPath]

        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()

        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe

        process.terminationHandler = { process in
            Logger.info("lua runtime terminated status=\(process.terminationStatus)")

            if easyBarLuaProcessGroupPID == process.processIdentifier {
                easyBarLuaProcessGroupPID = 0
            }
        }

        do {
            try process.run()
        } catch {
            Logger.error("failed to start lua runtime: \(error)")
            return
        }

        let pid = process.processIdentifier

        // Put Lua into its own process group so shutdown can kill the whole tree.
        _ = setpgid(pid, pid)
        easyBarLuaProcessGroupPID = pid

        self.process = process
        self.inputPipe = inPipe
        self.outputPipe = outPipe
        self.errorPipe = errPipe

        Logger.debug("lua runtime started pid=\(pid)")

        installOutputReadabilityHandler()
        installErrorReadabilityHandler()
    }

    /// Stops the Lua runtime and clears all pipe handlers.
    func shutdown() {
        guard let process else { return }

        Logger.debug("shutting down lua runtime pid=\(process.processIdentifier)")

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        try? inputPipe?.fileHandleForWriting.close()

        easyBarTerminateLuaProcessGroup()

        try? outputPipe?.fileHandleForReading.close()
        try? errorPipe?.fileHandleForReading.close()

        self.process = nil
        self.inputPipe = nil
        self.outputPipe = nil
        self.errorPipe = nil
    }

    /// Sends one encoded event line to the Lua runtime stdin.
    func send(_ string: String) {
        guard let pipe = inputPipe else {
            Logger.debug("cannot send event, lua stdin not available")
            return
        }

        writeQueue.async {
            guard let data = (string + "\n").data(using: .utf8) else { return }

            do {
                try pipe.fileHandleForWriting.write(contentsOf: data)
                Logger.debug("sent to lua stdin: \(string)")
            } catch {
                Logger.error("failed writing to lua stdin: \(error)")
            }
        }
    }

    /// Installs the stdout handler used for structured JSON widget updates.
    private func installOutputReadabilityHandler() {
        guard let pipe = outputPipe else { return }

        var buffer = Data()

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                return
            }

            buffer.append(data)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.prefix(upTo: newlineIndex)
                buffer.removeSubrange(...newlineIndex)

                guard let line = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !line.isEmpty
                else {
                    continue
                }

                Logger.debug("lua stdout raw: \(line)")

                NotificationCenter.default.post(
                    name: .easyBarLuaStdout,
                    object: line
                )
            }
        }
    }

    /// Installs the stderr handler used for Lua/widget logs and runtime failures.
    private func installErrorReadabilityHandler() {
        guard let pipe = errorPipe else { return }

        var buffer = Data()

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                return
            }

            buffer.append(data)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.prefix(upTo: newlineIndex)
                buffer.removeSubrange(...newlineIndex)

                guard let line = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !line.isEmpty
                else {
                    continue
                }

                self.handleLuaStderrLine(line)
            }
        }
    }

    /// Routes one stderr line from the Lua runtime into the normal logger.
    private func handleLuaStderrLine(_ line: String) {
        // Structured widget/runtime logs use:
        // EASYBAR_LOG<TAB>LEVEL<TAB>SOURCE<TAB>MESSAGE
        let prefix = "EASYBAR_LOG\t"

        guard line.hasPrefix(prefix) else {
            Logger.error("lua stderr: \(line)")
            return
        }

        let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)

        guard parts.count == 4 else {
            Logger.error("lua stderr: \(line)")
            return
        }

        let level = String(parts[1]).uppercased()
        let source = String(parts[2])
        let message = String(parts[3])

        let formatted = "lua[\(source)] \(message)"

        switch level {
        case "DEBUG":
            Logger.debug(formatted)
        case "INFO":
            Logger.info(formatted)
        case "WARN":
            Logger.warn(formatted)
        case "ERROR":
            Logger.error(formatted)
        default:
            Logger.info(formatted)
        }
    }

    /// Installs signal handlers once for clean Lua shutdown on exit/crash.
    private func installSignalHandlersIfNeeded() {
        guard !signalHandlersInstalled else { return }
        signalHandlersInstalled = true

        Darwin.signal(SIGINT, easyBarSignalHandler)
        Darwin.signal(SIGTERM, easyBarSignalHandler)
        Darwin.signal(SIGHUP, easyBarSignalHandler)
        Darwin.signal(SIGABRT, easyBarSignalHandler)
        Darwin.signal(SIGQUIT, easyBarSignalHandler)
    }
}

extension Notification.Name {
    static let easyBarLuaStdout = Notification.Name("easybar.lua.stdout")
}
