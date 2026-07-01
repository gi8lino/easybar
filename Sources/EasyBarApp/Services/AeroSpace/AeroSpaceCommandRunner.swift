import EasyBarShared
import Foundation

/// Runs the AeroSpace CLI and returns trimmed stdout.
final class AeroSpaceCommandRunner {
  /// Logger used for AeroSpace command diagnostics.
  private let logger: ProcessLogger
  /// Resolves the AeroSpace executable path.
  private let executablePathResolver: () -> String?

  /// Creates one AeroSpace command runner.
  init(
    logger: ProcessLogger,
    executablePathResolver: @escaping () -> String? = AeroSpaceCommandRunner.defaultExecutablePath
  ) {
    self.logger = logger
    self.executablePathResolver = executablePathResolver
  }

  /// Executes one AeroSpace command.
  func run(arguments: [String]) -> String? {
    guard let executable = executablePathResolver() else {
      logger.debug("aerospace executable not found")
      return nil
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    let outputHandle = outputPipe.fileHandleForReading
    let errorHandle = errorPipe.fileHandleForReading

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

    let outputReader = PipeReader(handle: outputHandle)
    let errorReader = PipeReader(handle: errorHandle)
    outputReader.start()
    errorReader.start()
    process.waitUntilExit()

    let outputResult = outputReader.finish()
    let errorResult = errorReader.finish()

    guard case .success(let outputData) = outputResult else {
      if case .failure(let error) = outputResult {
        logger.debug(
          "failed to read aerospace output",
          .field("args", arguments.joined(separator: " ")),
          .field("error", error),
        )
      }
      return nil
    }

    let errorData = (try? errorResult.get()) ?? Data()

    if process.terminationStatus != 0 {
      let stderr = String(data: errorData, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)

      logger.debug(
        "aerospace command exited",
        .field("status", process.terminationStatus),
        .field("args", arguments.joined(separator: " ")),
        .field("stderr_bytes", stderr?.utf8.count ?? 0)
      )
    }

    return String(data: outputData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Resolves the AeroSpace binary path.
  private static func defaultExecutablePath() -> String? {
    let candidates = [
      "/opt/homebrew/bin/aerospace",
      "/usr/local/bin/aerospace",
      "/Applications/AeroSpace.app/Contents/MacOS/aerospace",
    ]

    let fileManager = FileManager.default
    return candidates.first(where: { fileManager.isExecutableFile(atPath: $0) })
  }
}

/// Reads one process pipe while the subprocess is still running.
private final class PipeReader {
  private let handle: FileHandle
  private let group = DispatchGroup()
  private var result: Result<Data, Error> = .success(Data())

  init(handle: FileHandle) {
    self.handle = handle
  }

  func start() {
    group.enter()
    DispatchQueue.global(qos: .utility).async { [handle] in
      defer { self.group.leave() }

      do {
        self.result = .success(try handle.readToEnd() ?? Data())
      } catch {
        self.result = .failure(error)
      }
    }
  }

  func finish() -> Result<Data, Error> {
    group.wait()
    return result
  }
}
