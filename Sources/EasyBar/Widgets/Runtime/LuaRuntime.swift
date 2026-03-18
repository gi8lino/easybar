import Foundation

/// Facade for the Lua runtime used by scripted widgets.
///
/// Process lifecycle, transport, and log routing are split into dedicated helpers.
final class LuaRuntime {

    static let shared = LuaRuntime()

    private let processController = LuaProcessController()
    private let transport = LuaTransport()

    private init() {}

    /// Starts the Lua runtime if it is not already running.
    func start() {
        guard let result = processController.start() else {
            return
        }

        transport.attach(
            input: result.input,
            output: result.output,
            error: result.error
        )
        transport.startReading()
    }

    /// Stops the Lua runtime and clears all pipe handlers.
    func shutdown() {
        transport.shutdown()
        processController.shutdown()
    }

    /// Sends one encoded event line to the Lua runtime stdin.
    func send(_ string: String) {
        transport.send(string)
    }
}
