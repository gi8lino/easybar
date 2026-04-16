import Foundation

/// Handles stdin/stdout/stderr transport for the Lua runtime process.
final class LuaTransport {
  private let stateQueue = DispatchQueue(label: "easybar.lua.transport.state")
  private let writeQueue = DispatchQueue(label: "easybar.lua.transport.write")
  private let logBridge = LuaLogBridge()

  private var generation: UInt64 = 0

  private(set) var inputPipe: Pipe?
  private(set) var outputPipe: Pipe?
  private(set) var errorPipe: Pipe?

  private var stdoutHandler: (@Sendable (String) -> Void)?

  /// Attaches the transport to the given process pipes.
  func attach(
    input: Pipe,
    output: Pipe,
    error: Pipe,
    stdoutHandler: @escaping @Sendable (String) -> Void
  ) {
    stateQueue.sync {
      stopReadabilityHandler(for: outputPipe)
      stopReadabilityHandler(for: errorPipe)

      inputPipe = input
      outputPipe = output
      errorPipe = error
      self.stdoutHandler = stdoutHandler
      generation &+= 1
    }
  }

  /// Installs stdout and stderr readability handlers.
  func startReading() {
    stateQueue.sync {
      let currentGeneration = generation
      let currentStdoutHandler = stdoutHandler
      installOutputReadabilityHandler(
        generation: currentGeneration,
        stdoutHandler: currentStdoutHandler
      )
      installErrorReadabilityHandler(generation: currentGeneration)
    }
  }

  /// Stops all readability handlers and closes pipes.
  func shutdown() {
    let pipes: (input: Pipe?, output: Pipe?, error: Pipe?) = stateQueue.sync {
      generation &+= 1

      stopReadabilityHandler(for: outputPipe)
      stopReadabilityHandler(for: errorPipe)

      let current = (inputPipe, outputPipe, errorPipe)

      inputPipe = nil
      outputPipe = nil
      errorPipe = nil
      stdoutHandler = nil

      return current
    }

    writeQueue.async {
      self.closeInputPipe(pipes.input)
      self.closeReadPipe(pipes.output)
      self.closeReadPipe(pipes.error)
    }
  }

  /// Sends one encoded event line to the Lua runtime stdin.
  func send(_ string: String) {
    guard let data = (string + "\n").data(using: .utf8) else { return }

    writeQueue.async { [weak self] in
      guard let self else { return }

      let pipe = self.stateQueue.sync { self.inputPipe }
      guard let pipe else {
        easybarLog.debug("cannot send event, lua stdin not available")
        return
      }

      do {
        try pipe.fileHandleForWriting.write(contentsOf: data)
        MetricsCoordinator.shared.recordLuaWrite()
        easybarLog.debug("sent to lua stdin: \(string)")
      } catch {
        easybarLog.error("failed writing to lua stdin: \(error)")
      }
    }
  }

  /// Installs the stdout handler used for structured JSON widget updates.
  private func installOutputReadabilityHandler(
    generation: UInt64,
    stdoutHandler: (@Sendable (String) -> Void)?
  ) {
    guard let pipe = outputPipe else { return }

    installReadabilityHandler(on: pipe, generation: generation) { line in
      MetricsCoordinator.shared.recordLuaStdoutLine()
      easybarLog.debug("lua stdout raw: \(line)")
      stdoutHandler?(line)
    }
  }

  /// Installs the stderr handler used for Lua/widget logs and runtime failures.
  private func installErrorReadabilityHandler(generation: UInt64) {
    guard let pipe = errorPipe else { return }

    installReadabilityHandler(on: pipe, generation: generation) { [logBridge] line in
      MetricsCoordinator.shared.recordLuaStderrLine()
      logBridge.handle(line)
    }
  }

  /// Installs one buffered newline-delimited readability handler.
  private func installReadabilityHandler(
    on pipe: Pipe,
    generation: UInt64,
    handleLine: @escaping (String) -> Void
  ) {
    var buffer = Data()

    pipe.fileHandleForReading.readabilityHandler = { [weak self, weak pipe] handle in
      guard let self else { return }
      guard let pipe else { return }

      let stillCurrent = self.stateQueue.sync {
        self.generation == generation && (pipe === self.outputPipe || pipe === self.errorPipe)
      }

      guard stillCurrent else {
        handle.readabilityHandler = nil
        return
      }

      let data = handle.availableData

      if data.isEmpty {
        if let line = self.decodeLine(from: buffer[...]) {
          handleLine(line)
        }

        buffer.removeAll()
        handle.readabilityHandler = nil
        return
      }

      buffer.append(data)

      while let newlineIndex = buffer.firstIndex(of: 0x0A) {
        let lineData = buffer.prefix(upTo: newlineIndex)
        buffer.removeSubrange(...newlineIndex)

        guard let line = self.decodeLine(from: lineData) else { continue }
        handleLine(line)
      }
    }
  }

  /// Decodes one non-empty UTF-8 line.
  private func decodeLine(from data: Data.SubSequence) -> String? {
    guard
      let line = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !line.isEmpty
    else {
      return nil
    }

    return line
  }

  /// Stops the readability handler for one output pipe.
  private func stopReadabilityHandler(for pipe: Pipe?) {
    pipe?.fileHandleForReading.readabilityHandler = nil
  }

  /// Closes the stdin write pipe when present.
  private func closeInputPipe(_ pipe: Pipe?) {
    try? pipe?.fileHandleForWriting.close()
  }

  /// Closes one stdout/stderr read pipe when present.
  private func closeReadPipe(_ pipe: Pipe?) {
    try? pipe?.fileHandleForReading.close()
  }
}
