import Foundation

/// Stream type currently being decoded from an AeroSpace subscription.
enum AeroSpaceSubscriptionStreamKind {
  case output
  case error
}

/// Buffers partial stdout/stderr lines from one AeroSpace subscription session.
struct AeroSpaceSubscriptionStreamBuffer {
  /// Maximum partial line buffer retained for one process stream.
  private static let maxBufferedBytes = 64 * 1024

  /// Partial stdout line buffer.
  private var output = Data()
  /// Partial stderr line buffer.
  private var error = Data()
  /// Whether stdout is currently discarding one oversized line fragment.
  private var isDroppingOversizedOutputLine = false
  /// Whether stderr is currently discarding one oversized line fragment.
  private var isDroppingOversizedErrorLine = false

  /// Clears all partial line state.
  mutating func clear() {
    output.removeAll(keepingCapacity: true)
    error.removeAll(keepingCapacity: true)
    isDroppingOversizedOutputLine = false
    isDroppingOversizedErrorLine = false
  }

  /// Appends stream data and returns all complete non-empty lines.
  mutating func append(
    data: Data,
    stream: AeroSpaceSubscriptionStreamKind
  ) -> (lines: [String], droppedBuffer: Bool) {
    switch stream {
    case .output:
      return Self.extractLines(
        appending: data,
        to: &output,
        isDroppingOversizedLine: &isDroppingOversizedOutputLine
      )
    case .error:
      return Self.extractLines(
        appending: data,
        to: &error,
        isDroppingOversizedLine: &isDroppingOversizedErrorLine
      )
    }
  }

  /// Extracts newline-delimited UTF-8 lines from one stream buffer.
  private static func extractLines(
    appending data: Data,
    to buffer: inout Data,
    isDroppingOversizedLine: inout Bool
  ) -> (lines: [String], droppedBuffer: Bool) {
    if isDroppingOversizedLine {
      guard let newlineIndex = data.firstIndex(of: 0x0A) else {
        return ([], false)
      }

      let nextIndex = data.index(after: newlineIndex)
      buffer.removeAll(keepingCapacity: true)
      if nextIndex < data.endIndex {
        buffer.append(data[nextIndex...])
      }
      isDroppingOversizedLine = false
    } else {
      buffer.append(data)
    }

    var lines: [String] = []
    var droppedBuffer = false

    while let newlineIndex = buffer.firstIndex(of: 0x0A) {
      let lineData = buffer[..<newlineIndex]
      let nextIndex = buffer.index(after: newlineIndex)
      buffer.removeSubrange(buffer.startIndex..<nextIndex)

      guard lineData.count <= maxBufferedBytes else {
        droppedBuffer = true
        continue
      }

      var lineBytes = Array(lineData)
      if lineBytes.last == 0x0D {
        lineBytes.removeLast()
      }

      let line = String(decoding: lineBytes, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }
      lines.append(line)
    }

    guard buffer.count <= maxBufferedBytes else {
      buffer.removeAll(keepingCapacity: true)
      isDroppingOversizedLine = true
      return (lines, true)
    }

    return (lines, droppedBuffer)
  }
}
