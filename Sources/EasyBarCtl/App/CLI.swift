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

      let socketPath = parsed.socketPath ?? defaultEasyBarSocketPath()

      switch parsed.action {
      case .validateConfig:
        try validateConfig(configPath: parsed.configPath, socketPath: socketPath, context: context)

      case .command(let command):
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

/// Resolves the control socket from the active shared runtime configuration.
private func defaultEasyBarSocketPath() -> String {
  if let runtime = try? SharedRuntimeConfig.load() {
    return runtime.easyBar.socketPath
  }

  return SharedRuntimeConfig.environmentDefaults().easyBar.socketPath
}
