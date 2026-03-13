import Foundation

/// Unix socket server used to receive external triggers.
final class SocketServer {

    private let socketPath = "/tmp/easybar.sock"
    private var listenFD: Int32 = -1

    /// Starts the socket listener.
    func start(handler: @escaping (IPCCommand) -> Void) {

        unlink(socketPath)

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else {
            Logger.info("failed to create socket")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        _ = socketPath.withCString { path in
            strncpy(&addr.sun_path.0, path, MemoryLayout.size(ofValue: addr.sun_path))
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        _ = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenFD, $0, addrLen)
            }
        }

        listen(listenFD, 5)

        Logger.info("socket listening on \(socketPath)")

        DispatchQueue.global(qos: .userInitiated).async {
            self.acceptLoop(handler: handler)
        }
    }

    /// Accepts incoming socket clients.
    private func acceptLoop(handler: @escaping (IPCCommand) -> Void) {

        while true {

            let client = accept(listenFD, nil, nil)
            if client < 0 { continue }

            var buffer = [UInt8](repeating: 0, count: 256)
            let count = read(client, &buffer, 255)

            if count > 0 {

                let string = String(bytes: buffer.prefix(count), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                Logger.debug("received command '\(string ?? "unknown")'")

                if let string,
                   let cmd = IPCCommand(rawValue: string) {

                    DispatchQueue.main.async {
                        handler(cmd)
                    }
                } else {
                    Logger.debug("unknown IPC command")
                }
            }

            close(client)
        }
    }
}
