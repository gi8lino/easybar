import Darwin
import Foundation
import EasyBarShared

final class NetworkAgentClient {
    static let shared = NetworkAgentClient()

    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let queue = DispatchQueue(label: "easybar.network-agent-client", qos: .utility)
    private let reconnectDelay: TimeInterval = 2

    private var socketFD: Int32 = -1
    private var running = false
    private var reconnectWorkItem: DispatchWorkItem?

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func start() {
        lock.lock()
        if running {
            lock.unlock()
            return
        }
        running = true
        lock.unlock()

        connect()
    }

    func stop() {
        lock.lock()
        running = false
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil

        let currentFD = socketFD
        socketFD = -1
        lock.unlock()

        if currentFD >= 0 {
            shutdown(currentFD, SHUT_RDWR)
            close(currentFD)
        }

        NativeWiFiStore.shared.clear()
    }

    private func connect() {
        queue.async {
            guard self.isRunning() else { return }

            let socketPath = resolvedSocketPath()
            guard let fd = self.openConnectedSocket(socketPath: socketPath) else {
                self.scheduleReconnect()
                return
            }

            self.lock.lock()
            self.socketFD = fd
            self.lock.unlock()

            Logger.info("network agent client connected socket=\(socketPath)")

            let request = NetworkAgentRequest(command: .subscribe)
            guard self.send(request, to: fd) else {
                Logger.warn("network agent client failed to send subscribe request")
                self.handleDisconnect(fd: fd)
                return
            }

            self.readLoop(fd: fd)
        }
    }

    private func readLoop(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        var pending = Data()

        while isRunning() {
            let count = read(fd, &buffer, buffer.count)

            guard count > 0 else {
                break
            }

            pending.append(contentsOf: buffer.prefix(count))

            while let newlineIndex = pending.firstIndex(of: 0x0A) {
                let line = pending.prefix(upTo: newlineIndex)
                pending.removeSubrange(...newlineIndex)

                guard !line.isEmpty else { continue }
                handleMessageData(Data(line))
            }
        }

        handleDisconnect(fd: fd)
    }

    private func handleMessageData(_ data: Data) {
        do {
            let message = try decoder.decode(NetworkAgentMessage.self, from: data)

            switch message.kind {
            case .subscribed:
                Logger.info("network agent client subscribed")

            case .snapshot:
                guard let snapshot = message.snapshot else { return }
                publish(snapshot: snapshot)

            case .pong:
                break

            case .error:
                Logger.warn("network agent error=\(message.message ?? "unknown")")
            }
        } catch {
            Logger.warn("network agent client failed to decode message: \(error)")
        }
    }

    private func handleDisconnect(fd: Int32) {
        lock.lock()
        if socketFD == fd {
            socketFD = -1
        }
        lock.unlock()

        shutdown(fd, SHUT_RDWR)
        close(fd)

        clearPublishedState()

        guard isRunning() else { return }

        Logger.info("network agent client disconnected")
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        lock.lock()
        reconnectWorkItem?.cancel()

        guard running else {
            lock.unlock()
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.connect()
        }

        reconnectWorkItem = workItem
        lock.unlock()

        queue.asyncAfter(deadline: .now() + reconnectDelay, execute: workItem)
    }

    private func send(_ request: NetworkAgentRequest, to fd: Int32) -> Bool {
        do {
            let data = try encoder.encode(request) + Data("\n".utf8)
            return data.withUnsafeBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return false }

                var sent = 0
                while sent < data.count {
                    let written = write(fd, base.advanced(by: sent), data.count - sent)
                    if written <= 0 {
                        return false
                    }
                    sent += written
                }

                return true
            }
        } catch {
            Logger.warn("network agent client failed to encode request: \(error)")
            return false
        }
    }

    private func isRunning() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    /// Returns the configured network agent socket path.
    private func resolvedSocketPath() -> String {
        Config.shared.networkAgentSocketPath
    }

    /// Opens and connects one Unix socket to the network agent.
    private func openConnectedSocket(socketPath: String) -> Int32? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            Logger.warn("network agent client failed to create socket")
            return nil
        }

        var addr = makeSockAddrUn(path: socketPath)
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, addrLen)
            }
        }

        guard connectResult == 0 else {
            Logger.info("network agent client connect failed socket=\(socketPath)")
            close(fd)
            return nil
        }

        return fd
    }

    /// Publishes one snapshot to the shared store on the main queue.
    private func publish(snapshot: NetworkAgentSnapshot) {
        DispatchQueue.main.async {
            NativeWiFiStore.shared.apply(snapshot: snapshot)
        }
    }

    /// Clears the published store state on the main queue.
    private func clearPublishedState() {
        DispatchQueue.main.async {
            NativeWiFiStore.shared.clear()
        }
    }
}
