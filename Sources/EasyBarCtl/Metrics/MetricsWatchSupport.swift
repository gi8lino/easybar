import Darwin
import EasyBarShared
import Foundation

/// Manages watch-mode terminal state.
final class WatchTerminal {
  /// Whether stdout is attached to an interactive terminal.
  private let interactive: Bool = isatty(STDOUT_FILENO) != 0
  /// Whether watch mode has switched into alternate-screen mode.
  private var activated = false

  /// Escape sequence used to clear the terminal before drawing a new frame.
  var redrawPrefix: String {
    interactive ? "\u{001B}[H\u{001B}[2J\u{001B}[3J" : ""
  }

  /// Enters alternate-screen mode and hides the cursor for watch rendering.
  func activate() {
    guard interactive, !activated else { return }
    activated = true
    // Use the alternate screen so watch mode does not leave partial frames behind.
    fputs("\u{001B}[?1049h\u{001B}[?25l\u{001B}[H\u{001B}[2J\u{001B}[3J", stdout)
    fflush(stdout)
  }

  /// Restores the normal terminal screen and cursor state.
  func restore() {
    guard interactive, activated else { return }
    activated = false
    fputs("\u{001B}[?25h\u{001B}[?1049l", stdout)
    fflush(stdout)
  }
}

/// Stores recent watch samples.
struct MetricsHistory {
  /// Maximum number of samples retained per metric series.
  let limit: Int
  /// Recent metric values keyed by metric identifier.
  private(set) var series: [String: [Double]] = [:]

  /// Adds one snapshot to all tracked watch-mode metric series.
  mutating func append(_ snapshot: IPC.MetricsSnapshot) {
    append(snapshot.process.cpuPercent ?? 0, for: "process.cpu")
    append(snapshot.lua.cpuPercent ?? 0, for: "lua.cpu")
    append(snapshot.runtime.eventsPerSecond, for: "runtime.events")
    append(snapshot.runtime.treeUpdatesPerSecond, for: "runtime.tree")
  }

  /// Returns the retained values for one metric series.
  func values(for key: String) -> [Double] {
    return series[key] ?? []
  }

  /// Adds one value to a metric series and trims it to the configured limit.
  private mutating func append(_ value: Double, for key: String) {
    var values = series[key] ?? []
    values.append(max(0, value))

    if values.count > limit {
      values.removeFirst(values.count - limit)
    }

    series[key] = values
  }
}
