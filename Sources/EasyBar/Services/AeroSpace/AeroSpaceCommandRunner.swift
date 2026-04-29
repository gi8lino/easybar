import EasyBarShared
import Foundation

/// Runs the AeroSpace CLI and returns trimmed stdout.
final class AeroSpaceCommandRunner {
  private let logger: ProcessLogger

  /// Creates one AeroSpace command runner.
  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Executes one AeroSpace command.
  func run(arguments: [String]) -> String? {
    guard let executable = resolveExecutablePath() else {
      logger.debug("aerospace executable not found")
      return nil
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    let outputHandle = pipe.fileHandleForReading

    do {
      try process.run()
    } catch {
      logger.debug(
        "failed to run aerospace",
        .field("args", arguments.joined(separator: " ")),
        .field("error", error),
      )
      return nil
    }

    process.waitUntilExit()

    let data: Data
    do {
      data = try outputHandle.readToEnd() ?? Data()
    } catch {
      logger.debug(
        "failed to read aerospace output",
        .field("args", arguments.joined(separator: " ")),
        .field("error", error),
      )
      return nil
    }

    if process.terminationStatus != 0 {
      logger.debug(
        "aerospace command exited",
        .field("status", process.terminationStatus),
        .field("args", arguments.joined(separator: " ")),
      )
    }

    return String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Resolves the AeroSpace binary path.
  private func resolveExecutablePath() -> String? {
    let candidates = [
      "/opt/homebrew/bin/aerospace",
      "/usr/local/bin/aerospace",
      "/Applications/AeroSpace.app/Contents/MacOS/aerospace",
    ]

    let fileManager = FileManager.default
    return candidates.first(where: { fileManager.isExecutableFile(atPath: $0) })
  }
}
