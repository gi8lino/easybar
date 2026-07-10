import Darwin
import EasyBarShared
import Foundation

/// Runs the AeroSpace CLI and returns trimmed stdout.
final class AeroSpaceCommandRunner {
  /// Logger used for AeroSpace command diagnostics.
  private let logger: ProcessLogger
  /// Resolves the AeroSpace executable path.
  private let executablePathResolver: () -> String?
  /// Maximum time one short-lived AeroSpace CLI command may run.
  private let commandTimeout: TimeInterval
  /// Maximum stdout or stderr bytes kept for one AeroSpace command.
  private let commandOutputLimit: Int

  /// Creates one AeroSpace command runner.
  init(
    logger: ProcessLogger,
    executablePathResolver: @escaping () -> String? = AeroSpaceCommandRunner.defaultExecutablePath,
    commandTimeout: TimeInterval = 5,
    commandOutputLimit: Int = 1_048_576
  ) {
    self.logger = logger
    self.executablePathResolver = executablePathResolver
    self.commandTimeout = max(0.001, commandTimeout)
    self.commandOutputLimit = max(1, commandOutputLimit)
  }

  /// Creates one configured AeroSpace process.
  func makeProcess(arguments: [String]) -> Process? {
    guard let executable = executablePathResolver() else {
      logger.debug("aerospace executable not found")
      return nil
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    return process
  }

  /// Executes one AeroSpace command.
  func run(arguments: [String]) -> String? {
    guard let process = makeProcess(arguments: arguments) else {
      return nil
    }

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    let outputHandle = outputPipe.fileHandleForReading
    let errorHandle = errorPipe.fileHandleForReading

    let exitSemaphore = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in
      exitSemaphore.signal()
    }

    do {
      try process.run()
    } catch {
      process.terminationHandler = nil
      logger.debug(
        "failed to run aerospace",
        .field("args", arguments.joined(separator: " ")),
        .field("error", error),
      )
      return nil
    }

    let outputReader = PipeReader(handle: outputHandle, maxBytes: commandOutputLimit)
    let errorReader = PipeReader(handle: errorHandle, maxBytes: commandOutputLimit)
    outputReader.start()
    errorReader.start()

    let didExit = waitForExit(
      process: process,
      arguments: arguments,
      exitSemaphore: exitSemaphore
    )
    process.terminationHandler = nil

    let outputResult = outputReader.finish()
    let errorResult = errorReader.finish()

    guard didExit else { return nil }

    guard case .success(let outputReadResult) = outputResult else {
      if case .failure(let error) = outputResult {
        logger.debug(
          "failed to read aerospace output",
          .field("args", arguments.joined(separator: " ")),
          .field("error", error),
        )
      }
      return nil
    }

    let errorReadResult = try? errorResult.get()
    let errorData = errorReadResult?.data ?? Data()

    if outputReadResult.exceededLimit {
      logger.warn(
        "aerospace command output exceeded limit",
        .field("args", arguments.joined(separator: " ")),
        .field("max_output_bytes", commandOutputLimit)
      )
      return nil
    }

    if errorReadResult?.exceededLimit == true {
      logger.warn(
        "aerospace command stderr exceeded limit",
        .field("args", arguments.joined(separator: " ")),
        .field("max_output_bytes", commandOutputLimit)
      )
    }

    let outputData = outputReadResult.data

    if process.terminationStatus != 0 {
      let stderr = String(data: errorData, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)

      logger.debug(
        "aerospace command exited",
        .field("status", process.terminationStatus),
        .field("args", arguments.joined(separator: " ")),
        .field("stderr_bytes", stderr?.utf8.count ?? 0)
      )
      return nil
    }

    return String(data: outputData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Waits for a short-lived AeroSpace CLI command and terminates it on timeout.
  private func waitForExit(
    process: Process,
    arguments: [String],
    exitSemaphore: DispatchSemaphore
  ) -> Bool {
    let deadline = DispatchTime.now() + dispatchTimeInterval(commandTimeout)
    guard exitSemaphore.wait(timeout: deadline) == .timedOut else {
      return true
    }

    logger.warn(
      "aerospace command timed out",
      .field("args", arguments.joined(separator: " ")),
      .field("timeout_seconds", commandTimeout)
    )

    terminateTimedOutProcess(process, exitSemaphore: exitSemaphore)
    return false
  }

  /// Converts one positive second value into a dispatch timeout interval.
  private func dispatchTimeInterval(_ seconds: TimeInterval) -> DispatchTimeInterval {
    return .milliseconds(Int(ceil(seconds * 1_000)))
  }

  /// Terminates one timed-out AeroSpace process with a SIGKILL fallback.
  private func terminateTimedOutProcess(
    _ process: Process,
    exitSemaphore: DispatchSemaphore
  ) {
    if process.isRunning {
      process.terminate()
    }

    if exitSemaphore.wait(timeout: .now() + .milliseconds(300)) == .success {
      return
    }

    if process.isRunning {
      kill(process.processIdentifier, SIGKILL)
      process.waitUntilExit()
    }
  }

  /// Resolves the AeroSpace binary path from `PATH`, then known install locations.
  static func defaultExecutablePath() -> String? {
    defaultExecutablePath(environment: ProcessInfo.processInfo.environment)
  }

  /// Resolves the AeroSpace binary path from one environment snapshot.
  static func defaultExecutablePath(environment: [String: String]) -> String? {
    let pathCandidates =
      environment[SharedEnvironmentKeys.path]?
      .split(separator: ":")
      .map(String.init)
      .filter { !$0.isEmpty }
      .map { URL(fileURLWithPath: $0).appendingPathComponent("aerospace").path } ?? []

    let fallbackCandidates = [
      "/opt/homebrew/bin/aerospace",
      "/usr/local/bin/aerospace",
      "/Applications/AeroSpace.app/Contents/MacOS/aerospace",
    ]

    let fileManager = FileManager.default
    return uniqueCandidates(pathCandidates + fallbackCandidates)
      .first(where: { fileManager.isExecutableFile(atPath: $0) })
  }

  /// Removes duplicate candidate paths while preserving lookup order.
  private static func uniqueCandidates(_ candidates: [String]) -> [String] {
    var seen = Set<String>()
    return candidates.filter { seen.insert($0).inserted }
  }
}

/// Reads one process pipe while the subprocess is still running.
private final class PipeReader {
  struct ReadResult {
    let data: Data
    let exceededLimit: Bool
  }

  private let handle: FileHandle
  private let maxBytes: Int
  private let group = DispatchGroup()
  private let result = LockedState<Result<ReadResult, Error>>(
    .success(ReadResult(data: Data(), exceededLimit: false))
  )

  init(handle: FileHandle, maxBytes: Int) {
    self.handle = handle
    self.maxBytes = max(1, maxBytes)
  }

  func start() {
    group.enter()
    DispatchQueue.global(qos: .utility).async { [handle, maxBytes] in
      defer { self.group.leave() }

      do {
        let result = try Self.readOutput(from: handle.fileDescriptor, maxBytes: maxBytes)
        self.result.withLock { $0 = .success(result) }
      } catch {
        self.result.withLock { $0 = .failure(error) }
      }
    }
  }

  func finish() -> Result<ReadResult, Error> {
    group.wait()
    return result.withLock { $0 }
  }

  private static func readOutput(from fd: Int32, maxBytes: Int) throws -> ReadResult {
    var output = Data()
    var exceededLimit = false
    var buffer = [UInt8](repeating: 0, count: 4096)

    while true {
      let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return 0 }
        return Darwin.read(fd, baseAddress, rawBuffer.count)
      }

      if bytesRead > 0 {
        let remainingBytes = max(0, maxBytes - output.count)
        if remainingBytes > 0 {
          output.append(contentsOf: buffer.prefix(min(bytesRead, remainingBytes)))
        }
        if bytesRead > remainingBytes {
          exceededLimit = true
        }
        continue
      }

      if bytesRead == 0 {
        return ReadResult(data: output, exceededLimit: exceededLimit)
      }

      let errnoValue = errno
      if errnoValue == EINTR {
        continue
      }

      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errnoValue))
    }
  }
}
