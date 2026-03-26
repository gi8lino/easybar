import Darwin
import Foundation
import EasyBarShared

final class NetworkSocketServer {
    private struct Subscriber {
        let fd: Int32
    }

    private let socketPath = defaultNetworkAgentSocketPath()
    private let stateLock = NSLock()
    private let subscribersLock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var provider: NetworkSnapshotProvider?
    private var listenFD: Int32 = -1
    private var running = false
    private var subscribers: [Int32: Subscriber] = [:]

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func start(provider: NetworkSnapshotProvider) {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !running else { return }

        self.provider = provider

        let socketDirectory = socketDirectoryPath(for: socketPath)

        do {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: socketDirectory, isDirectory: true),
                withIntermediateDirectories: true
            )
        } catch {
            AgentLogger.error("failed to create network socket directory at \(socketDirectory): \(error)")
            return
        }

        unlink(socketPath)

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else {
            AgentLogger.error("failed to create network agent socket")
            return
        }

        var addr = makeSockAddrUn(path: socketPath)
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(self.listenFD, $0, addrLen)
            }
        }

        guard bindResult == 0 else {
            AgentLogger.error("failed to bind network agent socket at \(socketPath)")
            close(listenFD)
            listenFD = -1
            return
        }

        guard listen(listenFD, 8) == 0 else {
            AgentLogger.error("failed to listen on network agent socket at \(socketPath)")
            close(listenFD)
            listenFD = -1
            return
        }

        running = true
        AgentLogger.info("network agent socket listening on \(socketPath)")

        DispatchQueue.global(qos: .userInitiated).async {
            self.acceptLoop()
        }
    }

    func stop() {
        stateLock.lock()
        let currentListenFD = listenFD
        let wasRunning = running
        running = false
        listenFD = -1
        stateLock.unlock()

        guard wasRunning else { return }

        if currentListenFD >= 0 {
            shutdown(currentListenFD, SHUT_RDWR)
            close(currentListenFD)
        }

        subscribersLock.lock()
        let currentSubscribers = subscribers.values
        subscribers.removeAll()
        subscribersLock.unlock()

        for subscriber in currentSubscribers {
            shutdown(subscriber.fd, SHUT_RDWR)
            close(subscriber.fd)
        }

        unlink(socketPath)
    }

    func broadcastSnapshots() {
        guard let provider else { return }

        subscribersLock.lock()
        let currentSubscribers = Array(subscribers.values)
        subscribersLock.unlock()

        let snapshot = provider.snapshot()

        for subscriber in currentSubscribers {
            let message = NetworkAgentMessage(kind: .snapshot, snapshot: snapshot)

            if !send(message, to: subscriber.fd) {
                removeSubscriber(fd: subscriber.fd)
            }
        }
    }

    private func acceptLoop() {
        while isRunning() {
            let clientFD = accept(listenFD, nil, nil)
            if clientFD < 0 {
                if !isRunning() {
                    break
                }
                continue
            }

            AgentLogger.debug("network agent accepted client fd=\(clientFD)")

            DispatchQueue.global(qos: .utility).async {
                self.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ clientFD: Int32) {
        guard let request = readRequest(from: clientFD) else {
            close(clientFD)
            return
        }

        AgentLogger.debug("network agent request fd=\(clientFD) command=\(request.command.rawValue)")

        switch request.command {
        case .ping:
            _ = send(NetworkAgentMessage(kind: .pong), to: clientFD)
            close(clientFD)

        case .fetch:
            guard let provider else {
                _ = send(NetworkAgentMessage(kind: .error, message: "provider_unavailable"), to: clientFD)
                close(clientFD)
                return
            }

            let snapshot = provider.snapshot()
            _ = send(NetworkAgentMessage(kind: .snapshot, snapshot: snapshot), to: clientFD)
            close(clientFD)

        case .subscribe:
            guard let provider else {
                _ = send(NetworkAgentMessage(kind: .error, message: "provider_unavailable"), to: clientFD)
                close(clientFD)
                return
            }

            subscribersLock.lock()
            subscribers[clientFD] = Subscriber(fd: clientFD)
            subscribersLock.unlock()
            AgentLogger.info("network agent subscriber added fd=\(clientFD)")

            if !send(NetworkAgentMessage(kind: .subscribed), to: clientFD) {
                removeSubscriber(fd: clientFD)
                return
            }

            let snapshot = provider.snapshot()
            if !send(NetworkAgentMessage(kind: .snapshot, snapshot: snapshot), to: clientFD) {
                removeSubscriber(fd: clientFD)
            }
        }
    }

    private func readRequest(from fd: Int32) -> NetworkAgentRequest? {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = read(fd, &buffer, buffer.count)

        guard count > 0 else { return nil }

        let raw = String(decoding: buffer.prefix(count), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = raw.data(using: .utf8) else { return nil }

        do {
            return try decoder.decode(NetworkAgentRequest.self, from: data)
        } catch {
            AgentLogger.warn("failed to decode network agent request: \(error)")
            return nil
        }
    }

    private func send(_ message: NetworkAgentMessage, to fd: Int32) -> Bool {
        do {
            let data = try encoder.encode(message) + Data("\n".utf8)
            return sendAll(fd, data)
        } catch {
            AgentLogger.warn("failed to encode network agent message: \(error)")
            return false
        }
    }

    private func sendAll(_ fd: Int32, _ data: Data) -> Bool {
        data.withUnsafeBytes { rawBuffer in
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
    }

    private func removeSubscriber(fd: Int32) {
        subscribersLock.lock()
        let existing = subscribers.removeValue(forKey: fd)
        subscribersLock.unlock()

        guard existing != nil else { return }
        AgentLogger.info("network agent subscriber removed fd=\(fd)")

        shutdown(fd, SHUT_RDWR)
        close(fd)
    }

    private func isRunning() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return running
    }
}
