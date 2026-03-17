import Foundation
import EasyBarShared

/// Unix socket server used to receive external triggers.
final class SocketServer {

    private let socketPath = defaultSocketPath()
    private var listenFD: Int32 = -1

    /// Starts the socket listener.
    func start(handler: @escaping (IPCCommand) -> Void) {
        let socketDirectory = socketDirectoryPath(for: socketPath)

        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: socketDirectory, isDirectory: true),
                withIntermediateDirectories: true
            )
        } catch {
            Logger.info("failed to create socket directory at \(socketDirectory): \(error)")
            return
        }

        unlink(socketPath)

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else {
            Logger.info("failed to create socket")
            return
        }

        var addr = makeSockAddrUn(path: socketPath)
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenFD, $0, addrLen)
            }
        }

        guard bindResult >= 0 else {
            Logger.info("failed to bind socket at \(socketPath)")
            close(listenFD)
            listenFD = -1
            return
        }

        guard listen(listenFD, 5) >= 0 else {
            Logger.info("failed to listen on socket at \(socketPath)")
            close(listenFD)
            listenFD = -1
            return
        }

        Logger.info("socket listening on \(socketPath)")

        DispatchQueue.global(qos: .userInitiated).async {
            self.acceptLoop(handler: handler)
        }
    }

    /// Accepts incoming socket clients.
    private func acceptLoop(handler: @escaping (IPCCommand) -> Void) {
        while true {
            let client = accept(listenFD, nil, nil)
            if client < 0 {
                continue
            }

            Logger.debug("socket accepted client")

            var buffer = [UInt8](repeating: 0, count: 256)
            let count = read(client, &buffer, 255)

            if count > 0 {
                let string = String(bytes: buffer.prefix(count), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                Logger.debug("socket received raw command '\(string ?? "unknown")'")

                if let string,
                   let cmd = IPCCommand(rawValue: string) {
                    Logger.debug("socket dispatching command '\(cmd.rawValue)'")

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
