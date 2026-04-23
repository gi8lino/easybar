import Foundation

/// Runs the AeroSpace CLI and returns trimmed stdout.
final class AeroSpaceCommandRunner {
  /// Executes one AeroSpace command.
  func run(arguments: [String]) -> String? {
    guard let executable = resolveExecutablePath() else {
      easybarLog.debug("aerospace executable not found")
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
      easybarLog.debug("failed to run aerospace \(arguments.joined(separator: " ")): \(error)")
      return nil
    }

    process.waitUntilExit()

    let data: Data
    do {
      data = try outputHandle.readToEnd() ?? Data()
    } catch {
      easybarLog.debug(
        "failed to read aerospace output args=\(arguments.joined(separator: " ")): \(error)"
      )
      return nil
    }

    if process.terminationStatus != 0 {
      easybarLog.debug(
        "aerospace command exited with status=\(process.terminationStatus) args=\(arguments.joined(separator: " "))"
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
