import EasyBarShared
import Foundation

/// Unix socket server used to receive external triggers.
final class SocketServer {
  /// Concrete line-delimited socket transport used by the server.
  private typealias Transport = LineSocketServerTransport<
    IPC.Request,
    IPC.Request,
    IPC.Message
  >

  /// Logger used for socket-server diagnostics.
  private let logger: ProcessLogger
  /// Shared runtime metrics collector.
  private let metricsCoordinator: MetricsCoordinator

  /// Active socket transport instance.
  private var transport: Transport
  /// Current Unix-domain socket path.
  private var socketPath: String
  /// Handler invoked for accepted non-metrics commands.
  private var commandHandler: ((IPC.Command) -> Void)?
  /// Handler invoked for config validation requests.
  private var validateConfigHandler: ((String?) async -> IPC.Message)?
  /// Whether the socket server has already been started.
  private var started = false

  /// Creates a socket server bound to the configured socket path.
  init(
    logger: ProcessLogger,
    socketPath: String = SharedPathDefaults.defaultEasyBarSocketPath,
    metricsCoordinator: MetricsCoordinator = MetricsCoordinator.shared
  ) {
    self.logger = logger
    self.socketPath = socketPath
    self.metricsCoordinator = metricsCoordinator
    transport = Self.makeTransport(
      socketPath: socketPath,
      metricsCoordinator: metricsCoordinator,
      logger: logger.child("transport")
    )
  }

  /// Starts the socket listener.
  func start(
    handler: @escaping (IPC.Command) -> Void,
    validateConfigHandler: @escaping (String?) async -> IPC.Message
  ) {
    guard !started else { return }

    started = true
    commandHandler = handler
    self.validateConfigHandler = validateConfigHandler

    let activeTransport = transport

    activeTransport.start { [weak self, weak activeTransport] clientFD, request in
      guard let self, let activeTransport else {
        return .close
      }

      return await self.handle(
        clientFD: clientFD,
        request: request,
        handler: handler,
        transport: activeTransport
      )
    }
  }

  /// Reloads the socket server when the configured socket path changed.
  func reloadConfiguration(socketPath updatedSocketPath: String) {
    guard updatedSocketPath != socketPath else { return }

    guard let commandHandler else {
      socketPath = updatedSocketPath
      transport = Self.makeTransport(
        socketPath: updatedSocketPath,
        metricsCoordinator: metricsCoordinator,
        logger: logger.child("transport")
      )
      return
    }

    logger.info(
      "restarting socket server",
      .field("old_path", "\(socketPath)"),
      .field("new_path", "\(updatedSocketPath)")
    )

    Task {
      await metricsCoordinator.resetStreaming()
    }
    transport.stop()

    socketPath = updatedSocketPath
    transport = Self.makeTransport(
      socketPath: updatedSocketPath,
      metricsCoordinator: metricsCoordinator,
      logger: logger.child("transport")
    )

    let activeTransport = transport

    activeTransport.start { [weak self, weak activeTransport] clientFD, request in
      guard let self, let activeTransport else {
        return .close
      }

      return await self.handle(
        clientFD: clientFD,
        request: request,
        handler: commandHandler,
        transport: activeTransport
      )
    }
  }

  /// Stops the socket listener.
  func stop() {
    started = false
    commandHandler = nil
    validateConfigHandler = nil

    Task {
      await metricsCoordinator.resetStreaming()
    }
    transport.stop()
  }

  /// Broadcasts one metrics payload to all active stream subscribers.
  func broadcastMetrics(_ snapshot: IPC.MetricsSnapshot) {
    let message = IPC.Message.metrics(snapshot)

    for subscriber in transport.subscribersSnapshot() {
      if !transport.send(message, to: subscriber.fd) {
        _ = transport.removeSubscriber(fd: subscriber.fd)
      }
    }
  }

  /// Handles one decoded IPC request.
  private func handle(
    clientFD: Int32,
    request: IPC.Request,
    handler: @escaping (IPC.Command) -> Void,
    transport: Transport
  ) async -> Transport.ClientDisposition {
    logger.debug("socket dispatching command '\(request.command.rawValue)'")

    switch request {
    case .metrics(let watch):
      return await handleMetricsRequest(
        clientFD: clientFD,
        watch: watch,
        request: request,
        transport: transport
      )

    case .validateConfig(let configPath):
      return await handleValidateConfigRequest(
        clientFD: clientFD,
        configPath: configPath,
        transport: transport
      )

    case .command(let command):
      _ = transport.send(.accepted, to: clientFD)
      handler(command)
      return .close
    }
  }

  /// Handles one metrics request.
  private func handleMetricsRequest(
    clientFD: Int32,
    watch: Bool,
    request: IPC.Request,
    transport: Transport
  ) async -> Transport.ClientDisposition {
    let snapshot = await metricsCoordinator.snapshot()
    let sent = transport.send(.metrics(snapshot), to: clientFD)

    guard sent else {
      return .close
    }

    guard watch else {
      return .close
    }

    transport.addSubscriber(request, for: clientFD)
    await metricsCoordinator.addStreamingSubscriber(fd: clientFD)

    return .keepOpen
  }

  /// Handles one config validation request using the app's real config validator.
  private func handleValidateConfigRequest(
    clientFD: Int32,
    configPath: String?,
    transport: Transport
  ) async -> Transport.ClientDisposition {
    guard let validateConfigHandler else {
      _ = transport.send(.rejected(message: "config validation unavailable"), to: clientFD)
      return .close
    }

    let response = await validateConfigHandler(configPath)
    _ = transport.send(response, to: clientFD)
    return .close
  }

  /// Creates one transport bound to the given socket path.
  private static func makeTransport(
    socketPath: String,
    metricsCoordinator: MetricsCoordinator,
    logger: ProcessLogger
  ) -> Transport {
    Transport(
      socketPath: socketPath,
      serverLabel: "easybar",
      logger: logger,
      onSubscriberRemoved: { fd in
        Task {
          await metricsCoordinator.removeStreamingSubscriber(fd: fd)
        }
      }
    )
  }
}
