import Darwin
import EasyBarShared
import Foundation

/// Sends one IPC command.
func sendCommand(_ command: IPC.Command, to socketPath: String, context: AppContext) throws {
  context.debug("sending command '\(command.rawValue)' to \(socketPath)")

  let transport = LineSocketClientTransport<IPC.Request, IPC.Message>(socketPath: socketPath)
  let response = try transport.send(request: .makeCommand(command))

  switch response {
  case .accepted:
    context.debug("decoded response kind='accepted' message='<nil>'")

  case .rejected(let message):
    context.debug("decoded response kind='rejected' message='\(message ?? "<nil>")'")
    throw AppError.message(message ?? "command rejected")

  case .configValidated:
    context.debug("decoded response kind='config_validated' message='<nil>'")
    throw AppError.message("unexpected config validation response")

  case .metrics:
    context.debug("decoded response kind='metrics' message='<nil>'")
    throw AppError.message("unexpected metrics response")
  }

  context.debug("command sent")
}

/// Fetches one metrics snapshot.
func fetchMetricsSnapshot(from socketPath: String, context: AppContext) throws
  -> IPC.MetricsSnapshot
{
  context.debug("requesting metrics snapshot from \(socketPath)")

  let transport = LineSocketClientTransport<IPC.Request, IPC.Message>(socketPath: socketPath)
  let response = try transport.send(request: .makeMetrics())

  switch response {
  case .metrics(let metrics):
    return metrics

  case .rejected(let message):
    throw AppError.message(message ?? "metrics unavailable")

  case .accepted, .configValidated:
    throw AppError.message("metrics unavailable")
  }
}

/// Streams live metrics.
func streamMetrics(to socketPath: String, context: AppContext) throws {
  let client = MetricsStreamClient(socketPath: socketPath)
  var history = MetricsHistory(limit: 32)
  let terminal = WatchTerminal()
  terminal.activate()
  defer { terminal.restore() }

  try client.stream(request: .makeMetrics(watch: true)) { message in
    switch message {
    case .metrics(let snapshot):
      history.append(snapshot)
      fputs(
        terminal.redrawPrefix + MetricsRenderer.watchText(snapshot, history: history),
        stdout
      )
      fflush(stdout)

    case .rejected(let message):
      throw AppError.message(message ?? "metrics rejected")

    case .accepted, .configValidated:
      return
    }
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

  let transport = LineSocketClientTransport<IPC.Request, IPC.Message>(socketPath: socketPath)
  let response = try transport.send(
    request: .makeValidateConfig(configPath: requestedConfigPath)
  )

  switch response {
  case .configValidated(let validatedPath):
    fputs("config valid: \(validatedPath)\n", stdout)

  case .rejected(let message):
    throw AppError.message(message ?? "config validation failed")

  case .accepted:
    throw AppError.message("config validation did not return a result")

  case .metrics:
    throw AppError.message("unexpected metrics response")
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
