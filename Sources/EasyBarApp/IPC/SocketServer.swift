import EasyBarShared
import Foundation

/// Unix socket server used to receive external triggers.
///
/// Lifecycle methods (`start`, `reloadConfiguration`, and `stop`) and
/// `broadcastMetrics` must be called from one serialized execution context.
/// Production code enforces this by owning the server inside
/// `RuntimeSocketCommandAdapter`, an actor. Transport callbacks may arrive on
/// background threads, but they do not mutate the server's lifecycle state.
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
    socketPath: String = SharedPathDefaults.easyBarSocketPath(
      in: resolvedRuntimeDirectory()
    ),
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

    let activeTransport = transport

    let didStart = activeTransport.start { [weak self, weak activeTransport] clientFD, request in
      guard let self, let activeTransport else {
        return .close
      }

      return self.handle(
        clientFD: clientFD,
        request: request,
        handler: handler,
        validateConfigHandler: validateConfigHandler,
        transport: activeTransport
      )
    }

    guard didStart else { return }

    started = true
    commandHandler = handler
    self.validateConfigHandler = validateConfigHandler
  }

  /// Reloads the socket server when the configured socket path changed.
  @discardableResult
  func reloadConfiguration(socketPath updatedSocketPath: String) -> Bool {
    guard updatedSocketPath != socketPath else { return true }

    guard let commandHandler else {
      socketPath = updatedSocketPath
      transport = Self.makeTransport(
        socketPath: updatedSocketPath,
        metricsCoordinator: metricsCoordinator,
        logger: logger.child("transport")
      )
      return true
    }

    logger.info(
      "restarting socket server",
      .field("old_path", "\(socketPath)"),
      .field("new_path", "\(updatedSocketPath)")
    )

    let replacementTransport = Self.makeTransport(
      socketPath: updatedSocketPath,
      metricsCoordinator: metricsCoordinator,
      logger: logger.child("transport")
    )

    let activeValidateConfigHandler: (String?) async -> IPC.Message =
      validateConfigHandler ?? { _ in
        .rejected(message: "config validation unavailable")
      }

    let didStart = replacementTransport.start {
      [weak self, weak replacementTransport] clientFD, request in
      guard let self, let replacementTransport else {
        return .close
      }

      return self.handle(
        clientFD: clientFD,
        request: request,
        handler: commandHandler,
        validateConfigHandler: activeValidateConfigHandler,
        transport: replacementTransport
      )
    }

    guard didStart else {
      logger.error(
        "socket server reload failed; keeping existing listener",
        .field("active_path", "\(socketPath)"),
        .field("requested_path", "\(updatedSocketPath)")
      )
      return false
    }

    let previousTransport = transport
    transport = replacementTransport
    socketPath = updatedSocketPath

    previousTransport.stop()
    SynchronousTask.run {
      await self.metricsCoordinator.resetStreaming()
    }
    return true
  }

  /// Stops the socket listener.
  func stop() {
    started = false
    commandHandler = nil
    validateConfigHandler = nil

    transport.stop()
    SynchronousTask.run {
      await self.metricsCoordinator.resetStreaming()
    }
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
    validateConfigHandler: @escaping (String?) async -> IPC.Message,
    transport: Transport
  ) -> Transport.ClientDisposition {
    logger.debug("socket dispatching command '\(request.command.rawValue)'")

    switch request {
    case .metrics(let watch):
      return handleMetricsRequest(
        clientFD: clientFD,
        watch: watch,
        request: request,
        transport: transport
      )

    case .validateConfig(let configPath):
      return handleValidateConfigRequest(
        clientFD: clientFD,
        configPath: configPath,
        validateConfigHandler: validateConfigHandler,
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
  ) -> Transport.ClientDisposition {
    let snapshot = SynchronousTask.run {
      await self.metricsCoordinator.snapshot()
    }
    let sent = transport.send(.metrics(snapshot), to: clientFD)

    guard sent else {
      return .close
    }

    guard watch else {
      return .close
    }

    transport.addSubscriber(request, for: clientFD)
    SynchronousTask.run {
      await self.metricsCoordinator.addStreamingSubscriber(fd: clientFD)
    }

    return .keepOpen
  }

  /// Handles one config validation request using the app's real config validator.
  private func handleValidateConfigRequest(
    clientFD: Int32,
    configPath: String?,
    validateConfigHandler: @escaping (String?) async -> IPC.Message,
    transport: Transport
  ) -> Transport.ClientDisposition {
    let response = SynchronousTask.run {
      await validateConfigHandler(configPath)
    }
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
        SynchronousTask.run {
          await metricsCoordinator.removeStreamingSubscriber(fd: fd)
        }
      }
    )
  }
}
