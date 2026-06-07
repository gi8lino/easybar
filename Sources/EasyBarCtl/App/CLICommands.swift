import Darwin
import EasyBarShared
import Foundation

/// Sends one IPC command.
func sendCommand(_ command: IPC.Command, to socketPath: String, context: AppContext) throws {
  context.debug("sending command '\(command.rawValue)' to \(socketPath)")

  let response = try sendIPCRequest(
    .makeCommand(command),
    to: socketPath,
    context: context
  )

  try expectAccepted(response, fallback: "command rejected")
  context.debug("command sent")
}

/// Fetches one metrics snapshot.
func fetchMetricsSnapshot(from socketPath: String, context: AppContext) throws
  -> IPC.MetricsSnapshot
{
  context.debug("requesting metrics snapshot from \(socketPath)")

  let response = try sendIPCRequest(.makeMetrics(), to: socketPath, context: context)
  return try expectMetrics(response, fallback: "metrics unavailable")
}

/// Streams live metrics.
func streamMetrics(to socketPath: String, context: AppContext) throws {
  let client = MetricsStreamClient(socketPath: socketPath)
  var history = MetricsHistory(limit: 32)
  let terminal = WatchTerminal()
  terminal.activate()
  defer { terminal.restore() }

  try client.stream(request: .makeMetrics(watch: true)) { message in
    guard let snapshot = try metricsSnapshot(fromStreamMessage: message) else { return }

    history.append(snapshot)
    fputs(
      terminal.redrawPrefix + MetricsRenderer.watchText(snapshot, history: history),
      stdout
    )
    fflush(stdout)
  }

  context.debug("metrics stream ended")
}

/// Asks the running EasyBar app to validate config through the control socket.
func validateConfig(configPath: String?, socketPath: String, context: AppContext) throws {
  let requestedConfigPath = explicitValidationConfigPath(configPath)

  if let requestedConfigPath {
    context.debug("requesting config validation for \(requestedConfigPath) through \(socketPath)")
  } else {
    context.debug("requesting default config validation through \(socketPath)")
  }

  let response = try sendIPCRequest(
    .makeValidateConfig(configPath: requestedConfigPath),
    to: socketPath,
    context: context
  )

  let validation = try expectConfigValidated(response, fallback: "config validation failed")
  fputs("config valid: \(validation.path)\n", stdout)
  for warning in validation.warnings {
    fputs("warning: \(warning)\n", stdout)
  }
}

/// Returns the explicit validation path from CLI or environment overrides.
private func explicitValidationConfigPath(_ configPath: String?) -> String? {
  if let configPath, !configPath.isEmpty {
    return configPath
  }

  let environmentPath = ProcessInfo.processInfo.environment[SharedEnvironmentKeys.configPath]
  guard let environmentPath, !environmentPath.isEmpty else {
    return nil
  }

  return environmentPath
}

/// Sends one IPC request and logs the decoded response shape.
private func sendIPCRequest(
  _ request: IPC.Request,
  to socketPath: String,
  context: AppContext
) throws -> IPC.Message {
  let transport = LineSocketClientTransport<IPC.Request, IPC.Message>(socketPath: socketPath)
  let response = try transport.send(request: request)

  context.debug(
    "decoded response kind='\(response.kind.rawValue)' message='\(response.message ?? "<nil>")'"
  )

  return response
}

/// Verifies that one IPC response accepted a fire-and-forget command.
private func expectAccepted(_ response: IPC.Message, fallback: String) throws {
  switch response {
  case .accepted:
    return

  case .rejected:
    throw rejectedResponseError(response, fallback: fallback)

  case .configValidated:
    throw AppError.message("unexpected config validation response")

  case .metrics:
    throw AppError.message("unexpected metrics response")
  }
}

/// Extracts one metrics snapshot from an IPC response.
private func expectMetrics(_ response: IPC.Message, fallback: String) throws -> IPC.MetricsSnapshot {
  switch response {
  case .metrics(let metrics):
    return metrics

  case .rejected:
    throw rejectedResponseError(response, fallback: fallback)

  case .accepted, .configValidated:
    throw AppError.message(fallback)
  }
}

/// Extracts one config validation result from an IPC response.
private func expectConfigValidated(_ response: IPC.Message, fallback: String) throws
  -> (path: String, warnings: [String])
{
  switch response {
  case .configValidated(let validatedPath, let warnings):
    return (validatedPath, warnings)

  case .rejected:
    throw rejectedResponseError(response, fallback: fallback)

  case .accepted:
    throw AppError.message("config validation did not return a result")

  case .metrics:
    throw AppError.message("unexpected metrics response")
  }
}

/// Returns a snapshot for metrics stream updates and ignores non-data control messages.
private func metricsSnapshot(fromStreamMessage message: IPC.Message) throws -> IPC.MetricsSnapshot? {
  switch message {
  case .metrics(let snapshot):
    return snapshot

  case .rejected:
    throw rejectedResponseError(message, fallback: "metrics rejected")

  case .accepted, .configValidated:
    return nil
  }
}

/// Builds one AppError from a rejected IPC response and a command-specific fallback.
private func rejectedResponseError(_ response: IPC.Message, fallback: String) -> AppError {
  AppError.message(response.message ?? fallback)
}
