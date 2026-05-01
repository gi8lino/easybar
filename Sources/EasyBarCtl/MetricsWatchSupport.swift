import Darwin
import EasyBarShared
import Foundation

/// Manages watch-mode terminal state.
final class WatchTerminal {
  private let interactive: Bool = isatty(STDOUT_FILENO) != 0
  private var activated = false

  var redrawPrefix: String {
    interactive ? "\u{001B}[H\u{001B}[2J\u{001B}[3J" : ""
  }

  /// Handles activate.
  func activate() {
    guard interactive, !activated else { return }
    activated = true
    // Use the alternate screen so watch mode does not leave partial frames behind.
    fputs("\u{001B}[?1049h\u{001B}[?25l\u{001B}[H\u{001B}[2J\u{001B}[3J", stdout)
    fflush(stdout)
  }

  /// Handles restore.
  func restore() {
    guard interactive, activated else { return }
    activated = false
    fputs("\u{001B}[?25h\u{001B}[?1049l", stdout)
    fflush(stdout)
  }
}

/// Stores recent watch samples.
struct MetricsHistory {
  let limit: Int
  private(set) var series: [String: [Double]] = [:]

  /// Handles append.
  mutating func append(_ snapshot: IPC.MetricsSnapshot) {
    append(snapshot.process.cpuPercent ?? 0, for: "process.cpu")
    append(snapshot.lua.cpuPercent ?? 0, for: "lua.cpu")
    append(snapshot.runtime.eventsPerSecond, for: "runtime.events")
    append(snapshot.runtime.treeUpdatesPerSecond, for: "runtime.tree")
  }

  /// Handles values.
  func values(for key: String) -> [Double] {
    series[key] ?? []
  }

  /// Handles append.
  private mutating func append(_ value: Double, for key: String) {
    var values = series[key] ?? []
    values.append(max(0, value))

    if values.count > limit {
      values.removeFirst(values.count - limit)
    }

    series[key] = values
  }
}
