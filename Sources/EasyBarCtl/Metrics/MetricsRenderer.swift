import EasyBarShared
import Foundation

/// Renders metrics output.
enum MetricsRenderer {
  /// Number of historical samples rendered in watch-mode sparklines.
  private static let watchGraphWidth = 32
  /// Minimum terminal width used for side-by-side watch tiles.
  private static let wideWatchMinimumWidth = 100
  /// Maximum live dashboard width, keeping related tile columns visually grouped.
  private static let wideWatchMaximumWidth = 120
  /// Formatter used for metrics snapshot timestamps.
  private static let timestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
  }()
  /// Formatter used for memory values.
  nonisolated(unsafe) private static let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .memory
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter
  }()

  /// Renders a complete one-shot metrics snapshot.
  static func snapshotText(_ snapshot: IPC.MetricsSnapshot) -> String {
    let sections = [
      header(snapshot, live: false),
      processes(snapshot),
      runtime(snapshot),
      subscriptions(snapshot),
      agents(snapshot),
      widgets(snapshot),
      events(snapshot),
    ]

    return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
  }

  /// Renders one live metrics frame for watch mode.
  static func watchText(
    _ snapshot: IPC.MetricsSnapshot,
    history: MetricsHistory,
    terminalWidth: Int = 80
  ) -> String {
    let dashboard =
      terminalWidth >= wideWatchMinimumWidth
      ? wideWatchDashboard(snapshot, terminalWidth: terminalWidth)
      : narrowWatchDashboard(snapshot, terminalWidth: terminalWidth)
    let sections = [
      header(snapshot, live: true),
      graphs(snapshot, history: history),
      dashboard,
    ]

    return sections.filter { !$0.isEmpty }.joined(separator: "\n\n") + "\n"
  }

  /// Renders the live dashboard as side-by-side tiles.
  private static func wideWatchDashboard(
    _ snapshot: IPC.MetricsSnapshot,
    terminalWidth: Int
  ) -> String {
    // Avoid writing into the final terminal column, which can trigger an extra wrapped line.
    let layoutWidth = min(wideWatchMaximumWidth - 1, terminalWidth - 1)
    let pairGap = 2
    let pairWidth = max(32, (layoutWidth - pairGap) / 2)
    let tileGap = 2
    let tileWidth = max(24, (layoutWidth - tileGap * 2) / 3)

    return [
      tileRow(
        [
          watchProcesses(snapshot),
          watchAgentActivity(snapshot),
        ],
        widths: [pairWidth, pairWidth],
        gap: pairGap
      ),
      tileRow(
        [
          watchRuntime(snapshot, width: tileWidth),
          watchLua(snapshot, width: tileWidth),
          watchDelivery(snapshot, width: tileWidth),
        ],
        widths: [tileWidth, tileWidth, tileWidth],
        gap: tileGap
      ),
      tileRow(
        [
          watchSubscriptions(snapshot, width: tileWidth),
          watchWidgets(snapshot, width: tileWidth),
          watchEvents(snapshot, width: tileWidth),
        ],
        widths: [tileWidth, tileWidth, tileWidth],
        gap: tileGap
      ),
    ].joined(separator: "\n\n")
  }

  /// Renders the same compact live tiles vertically for narrow terminals.
  private static func narrowWatchDashboard(
    _ snapshot: IPC.MetricsSnapshot,
    terminalWidth: Int
  ) -> String {
    let width = max(44, terminalWidth)
    return [
      watchProcesses(snapshot),
      watchAgentActivity(snapshot),
      watchRuntime(snapshot, width: width),
      watchLua(snapshot, width: width),
      watchDelivery(snapshot, width: width),
      watchSubscriptions(snapshot, width: width),
      watchWidgets(snapshot, width: width),
      watchEvents(snapshot, width: width),
    ].filter { !$0.isEmpty }.joined(separator: "\n\n")
  }

  /// Renders process resource usage for EasyBar, Lua, and both helper agents.
  private static func watchProcesses(_ snapshot: IPC.MetricsSnapshot) -> String {
    let processLines =
      [processLine(snapshot.process), processLine(snapshot.lua)]
      + snapshot.agents.map { processLine($0.process, name: $0.name) }
    return (["Processes", processHeader()] + processLines)
      .joined(separator: "\n")
  }

  /// Renders helper-agent connection and activity counters without repeating process resources.
  private static func watchAgentActivity(_ snapshot: IPC.MetricsSnapshot) -> String {
    let header = row([
      column("agent", width: 9),
      column("conn", width: 4),
      column("msgs", width: 10),
      column("rec", width: 4),
      column("ref", width: 4),
      column("err", width: 4),
    ])
    let body = snapshot.agents.map { agent in
      row([
        column(agent.name, width: 9),
        column(yesNo(agent.connected), width: 4),
        column("\(agent.messagesTotal) \(number(agent.messagesPerSecond))/s", width: 10),
        column(String(agent.reconnectsTotal), width: 4),
        column(String(agent.refreshesTotal), width: 4),
        column(String(agent.decodeErrorsTotal), width: 4),
      ])
    }
    return (["Agent activity", header] + body).joined(separator: "\n")
  }

  /// Renders runtime lifecycle status.
  private static func watchRuntime(_ snapshot: IPC.MetricsSnapshot, width: Int) -> String {
    let runtime = snapshot.runtime
    return [
      "Runtime",
      compactMetric("metrics clients", String(runtime.subscriberCount), width: width),
      compactMetric("Lua ready", yesNo(runtime.luaReady), width: width),
      compactMetric("Lua restarts", String(runtime.luaRestartCount), width: width),
      compactMetric("subscriptions", String(runtime.subscribedEventCount), width: width),
      compactMetric("sample", sampleInterval(snapshot.sampleIntervalSeconds), width: width),
    ].joined(separator: "\n")
  }

  /// Renders Lua transport, structured log, and input health counters.
  private static func watchLua(_ snapshot: IPC.MetricsSnapshot, width: Int) -> String {
    let runtime = snapshot.runtime
    let logs = runtime.luaLogLines.map(String.init) ?? "\(runtime.stderrLines) stderr"
    let warningAndErrors: String
    let rawStderr: String
    if let warnings = runtime.luaWarningLines,
      let errors = runtime.luaErrorLines,
      let raw = runtime.luaRawStderrLines
    {
      warningAndErrors = "\(warnings)/\(errors)"
      rawStderr = String(raw)
    } else {
      warningAndErrors = "-"
      rawStderr = "-"
    }

    return [
      "Lua",
      compactMetric(
        "reads/writes",
        "\(runtime.transportLines)/\(runtime.luaWrites)",
        width: width
      ),
      compactMetric("logs", logs, width: width),
      compactMetric("warn/error", warningAndErrors, width: width),
      compactMetric("raw stderr", rawStderr, width: width),
      compactMetric("decode errors", String(runtime.decodeErrors), width: width),
      compactMetric(
        "input overflow",
        String(runtime.luaRuntimeInputOverflows),
        width: width
      ),
    ].joined(separator: "\n")
  }

  /// Renders event delivery and widget-tree publication counters.
  private static func watchDelivery(_ snapshot: IPC.MetricsSnapshot, width: Int) -> String {
    let runtime = snapshot.runtime
    return [
      "Delivery",
      compactMetric(
        "events",
        "\(runtime.totalEvents) (\(number(runtime.eventsPerSecond))/s)",
        width: width
      ),
      compactMetric("app/widget", "\(runtime.appEvents)/\(runtime.widgetEvents)", width: width),
      compactMetric(
        "dropped",
        "\(runtime.droppedEvents) (\(number(runtime.droppedEventsPerSecond))/s)",
        width: width
      ),
      compactMetric(
        "coalesced",
        "\(runtime.coalescedEvents) (\(number(runtime.coalescedEventsPerSecond))/s)",
        width: width
      ),
      compactMetric(
        "queue/overflow",
        "\(runtime.luaEventQueueDepth)/\(runtime.luaEventQueueOverflows)",
        width: width
      ),
      compactMetric(
        "tree updates",
        "\(runtime.treeUpdates) (\(number(runtime.treeUpdatesPerSecond))/s)",
        width: width
      ),
    ].joined(separator: "\n")
  }

  /// Renders every global Lua event subscription in one compact tile.
  private static func watchSubscriptions(_ snapshot: IPC.MetricsSnapshot, width _: Int) -> String {
    guard let events = snapshot.runtime.subscribedEvents else {
      return "Subscriptions\nunavailable"
    }
    guard !events.isEmpty else { return "Subscriptions\nnone" }

    return (["Subscriptions (\(events.count))"] + events.map { subscription($0, compact: true) })
      .joined(separator: "\n")
  }

  /// Renders the busiest widget trees using compact aligned columns.
  private static func watchWidgets(_ snapshot: IPC.MetricsSnapshot, width: Int) -> String {
    guard !snapshot.widgets.isEmpty else { return "Widget trees (top 8)\nnone" }

    let updatesWidth = 4
    let nodesWidth = 5
    let ageWidth = 6
    let idWidth = max(10, width - updatesWidth - nodesWidth - ageWidth - 3)
    let lines = snapshot.widgets.map { widget in
      compactRow([
        column(widget.id, width: idWidth),
        column(String(widget.updatesTotal), width: updatesWidth, alignment: .right),
        column(String(widget.lastNodeCount), width: nodesWidth, alignment: .right),
        column(relative(widget.lastUpdatedAt), width: ageWidth, alignment: .right),
      ])
    }
    let header = compactRow([
      column("id", width: idWidth),
      column("upd", width: updatesWidth, alignment: .right),
      column("nodes", width: nodesWidth, alignment: .right),
      column("age", width: ageWidth, alignment: .right),
    ])
    return (["Widget trees (top 8)", header] + lines)
      .joined(separator: "\n")
  }

  /// Renders the highest-volume events using compact aligned columns.
  private static func watchEvents(_ snapshot: IPC.MetricsSnapshot, width: Int) -> String {
    guard !snapshot.events.isEmpty else { return "Events (top 8)\nnone" }

    let totalWidth = 5
    let rateWidth = 6
    let droppedWidth = 4
    let coalescedWidth = 4
    let nameWidth = max(
      8,
      width - totalWidth - rateWidth - droppedWidth - coalescedWidth - 4
    )
    let lines = snapshot.events.map { event in
      compactRow([
        column(event.name, width: nameWidth),
        column(String(event.total), width: totalWidth, alignment: .right),
        column("\(number(event.perSecond))/s", width: rateWidth, alignment: .right),
        column(String(event.droppedTotal), width: droppedWidth, alignment: .right),
        column(String(event.coalescedTotal), width: coalescedWidth, alignment: .right),
      ])
    }
    let header = compactRow([
      column("name", width: nameWidth),
      column("tot", width: totalWidth, alignment: .right),
      column("rate", width: rateWidth, alignment: .right),
      column("drop", width: droppedWidth, alignment: .right),
      column("coal", width: coalescedWidth, alignment: .right),
    ])
    return (["Events (top 8)", header] + lines)
      .joined(separator: "\n")
  }

  /// Joins fixed-width columns with the single-space gaps used by compact tiles.
  private static func compactRow(_ columns: [String]) -> String {
    columns.joined(separator: " ")
  }

  /// Joins multiline tiles horizontally, padding shorter tiles with blank lines.
  private static func tileRow(_ tiles: [String], widths: [Int], gap: Int) -> String {
    guard tiles.count == widths.count else { return tiles.joined(separator: "\n\n") }

    let tileLines = tiles.map { $0.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) }
    let height = tileLines.map(\.count).max() ?? 0
    let separator = String(repeating: " ", count: max(1, gap))

    return (0..<height).map { lineIndex in
      zip(tileLines, widths).map { lines, width in
        column(lineIndex < lines.count ? lines[lineIndex] : "", width: width)
      }.joined(separator: separator)
    }.joined(separator: "\n")
  }

  /// Renders one aligned label/value line inside a compact tile.
  private static func compactMetric(_ label: String, _ value: String, width: Int) -> String {
    let valueWidth = min(max(7, value.count), max(7, width / 2))
    let labelWidth = max(8, width - valueWidth - 2)
    return row([
      column(label, width: labelWidth),
      column(value, width: valueWidth, alignment: .right),
    ])
  }

  /// Renders the metrics title and timestamp.
  private static func header(_ snapshot: IPC.MetricsSnapshot, live: Bool) -> String {
    let mode = live ? "live" : "snapshot"
    return "EasyBar metrics (\(mode))  \(timestamp(snapshot.timestamp))"
  }

  /// Renders watch-mode graph rows from recent metric history.
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

  /// Renders EasyBar and Lua process metrics.
  private static func processes(_ snapshot: IPC.MetricsSnapshot) -> String {
    let lines = [
      "Processes",
      processHeader(),
      processLine(snapshot.process),
      processLine(snapshot.lua),
    ]
    return lines.joined(separator: "\n")
  }

  /// Renders the global event names forwarded to the Lua runtime.
  private static func subscriptions(_ snapshot: IPC.MetricsSnapshot) -> String {
    guard let events = snapshot.runtime.subscribedEvents else { return "" }
    guard !events.isEmpty else { return "Subscribed events\nnone" }

    return (["Subscribed events (\(events.count))"] + events.map { "- \(subscription($0))" })
      .joined(separator: "\n")
  }

  /// Formats internal timer subscription keys as widget-oriented intervals.
  private static func subscription(_ event: String, compact: Bool = false) -> String {
    let parts = event.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
    guard parts.count == 3,
      parts[0] == "interval_tick",
      !parts[1].isEmpty,
      let seconds = Double(parts[2]),
      seconds > 0
    else {
      return event
    }

    let interval = duration(seconds)
    return compact ? "\(parts[1]) (\(interval))" : "\(parts[1]) (every \(interval))"
  }

  /// Formats one positive interval using the largest exact unit.
  private static func duration(_ seconds: Double) -> String {
    if seconds.truncatingRemainder(dividingBy: 3600) == 0 {
      return "\(compactNumber(seconds / 3600))h"
    }
    if seconds.truncatingRemainder(dividingBy: 60) == 0 {
      return "\(compactNumber(seconds / 60))m"
    }
    return "\(compactNumber(seconds))s"
  }

  /// Formats interval values without a redundant decimal for whole numbers.
  private static func compactNumber(_ value: Double) -> String {
    if value.rounded() == value {
      return String(Int(value))
    }
    return number(value)
  }

  /// Renders runtime counters and rates.
  private static func runtime(_ snapshot: IPC.MetricsSnapshot) -> String {
    let runtime = snapshot.runtime

    var lines = [
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
        column("input_overflow", width: 16),
        column(String(runtime.luaRuntimeInputOverflows), width: 18),
        column("event_overflow", width: 16),
        column(String(runtime.luaEventQueueOverflows), width: 18),
      ]),
      row([
        column("event_queue", width: 16),
        column(String(runtime.luaEventQueueDepth), width: 18),
        column(
          runtime.luaLogLines == nil ? "lua_stderr" : "lua_logs",
          width: 16
        ),
        column(
          String(runtime.luaLogLines ?? runtime.stderrLines),
          width: 18
        ),
      ]),
      row([
        column("lua_reads", width: 16),
        column(String(runtime.transportLines), width: 18),
        column("lua_writes", width: 16),
        column(String(runtime.luaWrites), width: 18),
      ]),
    ]

    if let warningLines = runtime.luaWarningLines,
      let errorLines = runtime.luaErrorLines,
      let rawStderrLines = runtime.luaRawStderrLines
    {
      lines.append(
        row([
          column("lua_warn", width: 16),
          column(String(warningLines), width: 18),
          column("lua_error", width: 16),
          column(String(errorLines), width: 18),
        ])
      )
      lines.append(
        row([
          column("lua_raw_stderr", width: 16),
          column(String(rawStderrLines), width: 18),
          column("", width: 16),
          column("", width: 18),
        ])
      )
    }

    lines.append(
      row([
        column("last_tree", width: 16),
        column(runtime.lastTreeRoot ?? "-", width: 18),
        column("tree_nodes", width: 16),
        column(runtime.lastTreeNodeCount.map(String.init) ?? "-", width: 18),
      ])
    )
    lines.append(
      row([
        column("last_tree_age", width: 16),
        column(relative(runtime.lastTreeAt), width: 18),
        column("sample", width: 16),
        column(sampleInterval(snapshot.sampleIntervalSeconds), width: 18),
      ])
    )

    return lines.joined(separator: "\n")
  }

  /// Renders per-agent connection and process metrics.
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

  /// Renders per-widget update metrics.
  private static func widgets(_ snapshot: IPC.MetricsSnapshot) -> String {
    guard !snapshot.widgets.isEmpty else {
      return "Widget trees (top 8)\nnone"
    }

    let header = row([
      column("id", width: 24),
      column("updates", width: 12),
      column("nodes", width: 6),
      column("last", width: 6),
    ])

    let body = snapshot.widgets.map { widget in
      row([
        column(widget.id, width: 24),
        column("\(widget.updatesTotal) (\(number(widget.updatesPerSecond))/s)", width: 12),
        column(String(widget.lastNodeCount), width: 6),
        column(relative(widget.lastUpdatedAt), width: 6),
      ])
    }

    return (["Widget trees (top 8)", header] + body).joined(separator: "\n")
  }

  /// Renders per-event totals, rates, drops, and coalescing counts.
  private static func events(_ snapshot: IPC.MetricsSnapshot) -> String {
    guard !snapshot.events.isEmpty else {
      return "Events (top 8)\nnone"
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

    return (["Events (top 8)", header] + body).joined(separator: "\n")
  }

  /// Renders the shared process table header.
  private static func processHeader() -> String {
    row([
      column("name", width: 10),
      column("pid", width: 7),
      column("cpu", width: 8),
      column("mem", width: 10),
      column("thr", width: 5),
    ])
  }

  /// Renders one process metrics row.
  private static func processLine(_ process: IPC.ProcessMetrics, name: String? = nil) -> String {
    row([
      column(name ?? process.name, width: 10),
      column(process.pid.map(String.init) ?? "-", width: 7),
      column(percent(process.cpuPercent), width: 8),
      column(bytes(process.residentSizeBytes), width: 10),
      column(process.threadCount.map(String.init) ?? "-", width: 5),
    ])
  }

  /// Renders one graph table row.
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

  /// Renders recent numeric values as a fixed-width sparkline.
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

  /// Formats a snapshot timestamp for display.
  private static func timestamp(_ date: Date) -> String {
    return timestampFormatter.string(from: date)
  }

  /// Formats an optional date as elapsed seconds from now.
  private static func relative(_ date: Date?) -> String {
    guard let date else { return "-" }

    let delta = max(0, Int(Date().timeIntervalSince(date)))
    return "\(delta)s"
  }

  /// Formats a Boolean value as `yes` or `no`.
  private static func yesNo(_ value: Bool) -> String {
    return value ? "yes" : "no"
  }

  /// Formats an optional numeric metric value.
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

  /// Formats an optional percentage metric value.
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

  /// Formats an optional byte count.
  private static func bytes(_ value: UInt64?) -> String {
    guard let value else { return "-" }
    return byteFormatter.string(fromByteCount: Int64(value))
  }

  /// Formats the metrics sample interval.
  private static func sampleInterval(_ value: Double) -> String {
    return "\(number(value))s"
  }

  /// Returns the arithmetic mean for a series of values.
  private static func average(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
  }

  /// Joins preformatted columns into one table row.
  private static func row(_ columns: [String]) -> String {
    return columns.joined(separator: "  ")
  }

  /// Horizontal alignment for fixed-width table columns.
  private enum ColumnAlignment {
    /// Left-aligns column text.
    case left
    /// Right-aligns column text.
    case right
  }

  /// Pads or truncates one value to a fixed-width column.
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
