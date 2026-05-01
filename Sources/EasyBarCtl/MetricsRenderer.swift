import EasyBarShared
import Foundation

/// Renders metrics output.
enum MetricsRenderer {
  private static let watchGraphWidth = 32
  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
  }()
  private static let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .memory
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter
  }()

  /// Handles snapshot text.
  static func snapshotText(_ snapshot: IPC.MetricsSnapshot) -> String {
    let sections = [
      header(snapshot, live: false),
      processes(snapshot),
      runtime(snapshot),
      agents(snapshot),
      widgets(snapshot),
      events(snapshot),
    ]

    return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
  }

  /// Handles watch text.
  static func watchText(_ snapshot: IPC.MetricsSnapshot, history: MetricsHistory) -> String {
    let sections = [
      header(snapshot, live: true),
      graphs(snapshot, history: history),
      processes(snapshot),
      runtime(snapshot),
      agents(snapshot),
      widgets(snapshot),
      events(snapshot),
    ]

    return sections.filter { !$0.isEmpty }.joined(separator: "\n\n") + "\n"
  }

  /// Handles header.
  private static func header(_ snapshot: IPC.MetricsSnapshot, live: Bool) -> String {
    let mode = live ? "live" : "snapshot"
    return "EasyBar metrics (\(mode))  \(timestamp(snapshot.timestamp))"
  }

  /// Handles graphs.
  private static func graphs(_ snapshot: IPC.MetricsSnapshot, history: MetricsHistory) -> String {
    let lines = [
      row([
        column("metric", width: 10),
        column("now", width: 8, alignment: .right),
        column("avg", width: 8, alignment: .right),
        "history (\(watchGraphWidth))",
      ]),
      graphLine(
        label: "app cpu",
        current: percent(snapshot.process.cpuPercent),
        average: percent(average(history.values(for: "process.cpu"))),
        values: history.values(for: "process.cpu"),
        absoluteMax: 100,
        fixedWidth: watchGraphWidth
      ),
      graphLine(
        label: "lua cpu",
        current: percent(snapshot.lua.cpuPercent),
        average: percent(average(history.values(for: "lua.cpu"))),
        values: history.values(for: "lua.cpu"),
        absoluteMax: 100,
        fixedWidth: watchGraphWidth
      ),
      graphLine(
        label: "events/s",
        current: number(snapshot.runtime.eventsPerSecond),
        average: number(average(history.values(for: "runtime.events"))),
        values: history.values(for: "runtime.events"),
        fixedWidth: watchGraphWidth
      ),
      graphLine(
        label: "tree/s",
        current: number(snapshot.runtime.treeUpdatesPerSecond),
        average: number(average(history.values(for: "runtime.tree"))),
        values: history.values(for: "runtime.tree"),
        fixedWidth: watchGraphWidth
      ),
    ]

    return (["Graphs"] + lines).joined(separator: "\n")
  }

  /// Handles processes.
  private static func processes(_ snapshot: IPC.MetricsSnapshot) -> String {
    let lines = [
      "Processes",
      processHeader(),
      processLine(snapshot.process),
      processLine(snapshot.lua),
    ]
    return lines.joined(separator: "\n")
  }

  /// Handles runtime.
  private static func runtime(_ snapshot: IPC.MetricsSnapshot) -> String {
    let runtime = snapshot.runtime

    return [
      "Runtime",
      row([
        column("metric", width: 16),
        column("value", width: 18),
        column("metric", width: 16),
        column("value", width: 18),
      ]),
      row([
        column("subscribers", width: 16),
        column(String(runtime.subscriberCount), width: 18),
        column("lua_ready", width: 16),
        column(yesNo(runtime.luaReady), width: 18),
      ]),
      row([
        column("subscribed", width: 16),
        column(String(runtime.subscribedEventCount), width: 18),
        column("lua_restarts", width: 16),
        column(String(runtime.luaRestartCount), width: 18),
      ]),
      row([
        column("events", width: 16),
        column(String(runtime.totalEvents), width: 18),
        column("events_rate", width: 16),
        column("\(number(runtime.eventsPerSecond))/s", width: 18),
      ]),
      row([
        column("dropped", width: 16),
        column(String(runtime.droppedEvents), width: 18),
        column("dropped_rate", width: 16),
        column("\(number(runtime.droppedEventsPerSecond))/s", width: 18),
      ]),
      row([
        column("coalesced", width: 16),
        column(String(runtime.coalescedEvents), width: 18),
        column("coal_rate", width: 16),
        column("\(number(runtime.coalescedEventsPerSecond))/s", width: 18),
      ]),
      row([
        column("app/widget", width: 16),
        column("\(runtime.appEvents)/\(runtime.widgetEvents)", width: 18),
        column("tree_updates", width: 16),
        column(String(runtime.treeUpdates), width: 18),
      ]),
      row([
        column("tree_rate", width: 16),
        column("\(number(runtime.treeUpdatesPerSecond))/s", width: 18),
        column("decode_errors", width: 16),
        column(String(runtime.decodeErrors), width: 18),
      ]),
      row([
        column("stdout/stderr", width: 16),
        column("\(runtime.stdoutLines)/\(runtime.stderrLines)", width: 18),
        column("lua_writes", width: 16),
        column(String(runtime.luaWrites), width: 18),
      ]),
      row([
        column("last_tree", width: 16),
        column(runtime.lastTreeRoot ?? "-", width: 18),
        column("tree_nodes", width: 16),
        column(runtime.lastTreeNodeCount.map(String.init) ?? "-", width: 18),
      ]),
      row([
        column("last_tree_age", width: 16),
        column(relative(runtime.lastTreeAt), width: 18),
        column("sample", width: 16),
        column(sampleInterval(snapshot.sampleIntervalSeconds), width: 18),
      ]),
    ].joined(separator: "\n")
  }

  /// Handles agents.
  private static func agents(_ snapshot: IPC.MetricsSnapshot) -> String {
    let header = row([
      column("name", width: 10),
      column("conn", width: 6),
      column("pid", width: 7),
      column("cpu", width: 8),
      column("mem", width: 10),
      column("thr", width: 5),
      column("msgs", width: 11),
      column("reconn", width: 6),
      column("refresh", width: 7),
      column("decode", width: 6),
    ])

    let body = snapshot.agents.map { agent in
      row([
        column(agent.name, width: 10),
        column(yesNo(agent.connected), width: 6),
        column(agent.process.pid.map(String.init) ?? "-", width: 7),
        column(percent(agent.process.cpuPercent), width: 8),
        column(bytes(agent.process.residentSizeBytes), width: 10),
        column(agent.process.threadCount.map(String.init) ?? "-", width: 5),
        column("\(agent.messagesTotal) (\(number(agent.messagesPerSecond))/s)", width: 11),
        column(String(agent.reconnectsTotal), width: 6),
        column(String(agent.refreshesTotal), width: 7),
        column(String(agent.decodeErrorsTotal), width: 6),
      ])
    }

    return (["Agents", header] + body).joined(separator: "\n")
  }

  /// Handles widgets.
  private static func widgets(_ snapshot: IPC.MetricsSnapshot) -> String {
    guard !snapshot.widgets.isEmpty else {
      return "Widgets\nnone"
    }

    let header = row([
      column("id", width: 16),
      column("updates", width: 12),
      column("nodes", width: 6),
      column("last", width: 6),
    ])

    let body = snapshot.widgets.map { widget in
      row([
        column(widget.id, width: 16),
        column("\(widget.updatesTotal) (\(number(widget.updatesPerSecond))/s)", width: 12),
        column(String(widget.lastNodeCount), width: 6),
        column(relative(widget.lastUpdatedAt), width: 6),
      ])
    }

    return (["Widgets", header] + body).joined(separator: "\n")
  }

  /// Handles events.
  private static func events(_ snapshot: IPC.MetricsSnapshot) -> String {
    guard !snapshot.events.isEmpty else {
      return "Events\nnone"
    }

    let header = row([
      column("name", width: 18),
      column("total", width: 6),
      column("rate", width: 10),
      column("drop", width: 6),
      column("coal", width: 6),
    ])

    let body = snapshot.events.map { event in
      row([
        column(event.name, width: 18),
        column(String(event.total), width: 6),
        column("\(number(event.perSecond))/s", width: 10),
        column(String(event.droppedTotal), width: 6),
        column(String(event.coalescedTotal), width: 6),
      ])
    }

    return (["Events", header] + body).joined(separator: "\n")
  }

  /// Handles process header.
  private static func processHeader() -> String {
    row([
      column("name", width: 10),
      column("pid", width: 7),
      column("cpu", width: 8),
      column("mem", width: 10),
      column("thr", width: 5),
    ])
  }

  /// Handles process line.
  private static func processLine(_ process: IPC.ProcessMetrics) -> String {
    row([
      column(process.name, width: 10),
      column(process.pid.map(String.init) ?? "-", width: 7),
      column(percent(process.cpuPercent), width: 8),
      column(bytes(process.residentSizeBytes), width: 10),
      column(process.threadCount.map(String.init) ?? "-", width: 5),
    ])
  }

  /// Handles graph line.
  private static func graphLine(
    label: String,
    current: String,
    average: String,
    values: [Double],
    absoluteMax: Double? = nil,
    fixedWidth: Int
  ) -> String {
    row([
      column(label, width: 10),
      column(current, width: 8, alignment: .right),
      column(average, width: 8, alignment: .right),
      sparkline(values, absoluteMax: absoluteMax, fixedWidth: fixedWidth),
    ])
  }

  /// Handles sparkline.
  private static func sparkline(
    _ values: [Double],
    absoluteMax: Double? = nil,
    fixedWidth: Int
  ) -> String {
    guard fixedWidth > 0 else { return "[]" }
    guard !values.isEmpty else { return "[" + String(repeating: " ", count: fixedWidth) + "]" }

    let symbols = Array("▁▂▃▄▅▆▇█")
    let maxValue = absoluteMax ?? (values.max() ?? 0)
    let visibleValues = Array(values.suffix(fixedWidth))
    let leadingPadding = max(0, fixedWidth - visibleValues.count)

    guard maxValue > 0 else {
      return "[" + String(repeating: " ", count: leadingPadding)
        + String(repeating: String(symbols[0]), count: visibleValues.count) + "]"
    }

    let rendered = visibleValues.map { value -> Character in
      let normalized = min(max(value / maxValue, 0), 1)
      let index = Int((normalized * Double(symbols.count - 1)).rounded())
      return symbols[index]
    }

    return "[" + String(repeating: " ", count: leadingPadding) + String(rendered) + "]"
  }

  /// Handles timestamp.
  private static func timestamp(_ date: Date) -> String {
    timestampFormatter.string(from: date)
  }

  /// Handles relative.
  private static func relative(_ date: Date?) -> String {
    guard let date else { return "-" }

    let delta = max(0, Int(Date().timeIntervalSince(date)))
    return "\(delta)s"
  }

  /// Handles yes no.
  private static func yesNo(_ value: Bool) -> String {
    value ? "yes" : "no"
  }

  /// Handles number.
  private static func number(_ value: Double?) -> String {
    guard let value else { return "-" }

    if value == 0 {
      return "0.0"
    }

    if value < 1 {
      return String(format: "%.2f", value)
    }

    return String(format: "%.1f", value)
  }

  /// Handles percent.
  private static func percent(_ value: Double?) -> String {
    guard let value else { return "-" }

    if value == 0 {
      return "0.0%"
    }

    if value < 1 {
      return String(format: "%.2f%%", value)
    }

    return String(format: "%.1f%%", value)
  }

  /// Handles bytes.
  private static func bytes(_ value: UInt64?) -> String {
    guard let value else { return "-" }
    return byteFormatter.string(fromByteCount: Int64(value))
  }

  /// Handles sample interval.
  private static func sampleInterval(_ value: Double) -> String {
    "\(number(value))s"
  }

  /// Handles average.
  private static func average(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
  }

  /// Handles row.
  private static func row(_ columns: [String]) -> String {
    columns.joined(separator: "  ")
  }

  private enum ColumnAlignment {
    case left
    case right
  }

  /// Handles column.
  private static func column(_ value: String, width: Int, alignment: ColumnAlignment = .left)
    -> String
  {
    if value.count >= width {
      return String(value.prefix(width))
    }

    let padding = String(repeating: " ", count: width - value.count)

    switch alignment {
    case .left:
      return value + padding
    case .right:
      return padding + value
    }
  }
}
