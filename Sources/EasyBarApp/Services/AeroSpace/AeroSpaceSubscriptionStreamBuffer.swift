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

  /// Clears all partial line state.
  mutating func clear() {
    output.removeAll(keepingCapacity: true)
    error.removeAll(keepingCapacity: true)
  }

  /// Appends stream data and returns all complete non-empty lines.
  mutating func append(
    data: Data,
    stream: AeroSpaceSubscriptionStreamKind
  ) -> (lines: [String], droppedBuffer: Bool) {
    switch stream {
    case .output:
      return Self.extractLines(appending: data, to: &output)
    case .error:
      return Self.extractLines(appending: data, to: &error)
    }
  }

  /// Extracts newline-delimited UTF-8 lines from one stream buffer.
  private static func extractLines(
    appending data: Data,
    to buffer: inout Data
  ) -> (lines: [String], droppedBuffer: Bool) {
    buffer.append(data)

    var lines: [String] = []
    while let newlineIndex = buffer.firstIndex(of: 0x0A) {
      let lineData = buffer[..<newlineIndex]
      let nextIndex = buffer.index(after: newlineIndex)
      buffer.removeSubrange(buffer.startIndex..<nextIndex)

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
      return (lines, true)
    }

    return (lines, false)
  }
}
