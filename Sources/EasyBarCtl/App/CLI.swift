import Darwin
import EasyBarShared
import Foundation

/// CLI entry point.
@main
enum EasyBarCtlApp {
  /// Runs the CLI.
  static func main() {
    exit(AppController().run())
  }
}

/// Runs the CLI flow.
private struct AppController {
  /// Returns the exit code.
  func run() -> Int32 {
    do {
      let parsed = try parseArguments(CommandLine.arguments)
      let context = AppContext(debugEnabled: parsed.debugEnabled)

      switch parsed.action {
      case .validateConfig:
        let socketPath = try resolvedControlSocketPath(
          explicitPath: parsed.socketPath,
          context: context
        )
        try validateConfig(configPath: parsed.configPath, socketPath: socketPath, context: context)

      case .command(let command):
        let socketPath = try resolvedControlSocketPath(
          explicitPath: parsed.socketPath,
          context: context
        )
        if command == .metrics {
          if parsed.watchMetrics {
            try streamMetrics(to: socketPath, context: context)
          } else {
            let snapshot = try fetchMetricsSnapshot(from: socketPath, context: context)
            CLIOutput.printMetricsSnapshot(snapshot)
          }
        } else {
          try sendCommand(command, to: socketPath, context: context)
        }

      case .restartCalendarAgent:
        try restartCalendarAgent(socketPath: parsed.socketPath, context: context)

      case .restartNetworkAgent:
        try restartNetworkAgent(socketPath: parsed.socketPath, context: context)

      case .restartAgents:
        guard parsed.socketPath == nil else {
          throw AppError.message("--socket cannot be used with --restart-agents")
        }
        try restartAgents(context: context)
      }

      return 0
    } catch AppError.showUsage {
      CLIOutput.printUsage()
      return 1
    } catch AppError.showVersion {
      CLIOutput.printVersion()
      return 0
    } catch AppError.message(let message) {
      CLIOutput.printError(message)
    } catch {
      CLIOutput.printError("\(error)")
    }

    CLIOutput.printUsage()
    return 1
  }
}

/// Resolves the control socket and reports malformed shared configuration clearly.
private func resolvedControlSocketPath(
  explicitPath: String?,
  context: AppContext
) throws -> String {
  do {
    let resolution = try SharedRuntimeSocketResolver.controlSocket(explicitPath: explicitPath)
    logSocketResolution(resolution, kind: "control", context: context)
    return resolution.path
  } catch {
    throw AppError.message(
      "failed to resolve control socket from shared runtime config: "
        + "\(error.localizedDescription). Use --socket PATH to bypass config resolution."
    )
  }
}

/// Logs one resolved CLI socket source.
func logSocketResolution(
  _ resolution: SharedRuntimeSocketResolution,
  kind: String,
  context: AppContext
) {
  switch resolution.source {
  case .explicit:
    context.debug("resolved \(kind) socket from --socket: \(resolution.path)")

  case .sharedConfig(let path):
    context.debug(
      "resolved \(kind) socket from shared config \(path): \(resolution.path)"
    )
  }
}
