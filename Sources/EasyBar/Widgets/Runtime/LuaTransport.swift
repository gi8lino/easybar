import Foundation

/// Handles stdin/stdout/stderr transport for the Lua runtime process.
final class LuaTransport {

  private let writeQueue = DispatchQueue(label: "easybar.lua.write")
  private let logBridge = LuaLogBridge()

  private(set) var inputPipe: Pipe?
  private(set) var outputPipe: Pipe?
  private(set) var errorPipe: Pipe?

  /// Attaches the transport to the given process pipes.
  func attach(input: Pipe, output: Pipe, error: Pipe) {
    inputPipe = input
    outputPipe = output
    errorPipe = error
  }

  /// Installs stdout and stderr readability handlers.
  func startReading() {
    installOutputReadabilityHandler()
    installErrorReadabilityHandler()
  }

  /// Stops all readability handlers and closes pipes.
  func shutdown() {
    stopReadabilityHandler(for: outputPipe)
    stopReadabilityHandler(for: errorPipe)

    closeInputPipe()
    closeReadPipe(outputPipe)
    closeReadPipe(errorPipe)

    inputPipe = nil
    outputPipe = nil
    errorPipe = nil
  }

  /// Sends one encoded event line to the Lua runtime stdin.
  func send(_ string: String) {
    guard let pipe = inputPipe else {
      easybarLog.debug("cannot send event, lua stdin not available")
      return
    }

    writeQueue.async {
      guard let data = (string + "\n").data(using: .utf8) else { return }

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
  private func installOutputReadabilityHandler() {
    guard let pipe = outputPipe else { return }

    installReadabilityHandler(on: pipe) { line in
      MetricsCoordinator.shared.recordLuaStdoutLine()
      easybarLog.debug("lua stdout raw: \(line)")
      NotificationCenter.default.post(name: .easyBarLuaStdout, object: line)
    }
  }

  /// Installs the stderr handler used for Lua/widget logs and runtime failures.
  private func installErrorReadabilityHandler() {
    guard let pipe = errorPipe else { return }

    installReadabilityHandler(on: pipe) { [logBridge] line in
      MetricsCoordinator.shared.recordLuaStderrLine()
      logBridge.handle(line)
    }
  }

  /// Installs one buffered newline-delimited readability handler.
  private func installReadabilityHandler(
    on pipe: Pipe,
    handleLine: @escaping (String) -> Void
  ) {
    var buffer = Data()

    pipe.fileHandleForReading.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }

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
  private func closeInputPipe() {
    try? inputPipe?.fileHandleForWriting.close()
  }

  /// Closes one stdout/stderr read pipe when present.
  private func closeReadPipe(_ pipe: Pipe?) {
    try? pipe?.fileHandleForReading.close()
  }
}

extension Notification.Name {
  static let easyBarLuaStdout = Notification.Name("easybar.lua.stdout")
}
