import Darwin
import EasyBarShared
import Foundation

/// The EasyBar CLI entry point.
@main
enum EasyBarCtlApp {
  /// Runs the CLI process.
  static func main() {
    exit(AppController().run())
  }
}

/// Coordinates argument parsing, command dispatch, and CLI output.
private struct AppController {
  /// Runs the CLI command flow and returns the process exit code.
  func run() -> Int32 {
    do {
      let parsed = try parseArguments(CommandLine.arguments)
      let context = AppContext(debugEnabled: parsed.debugEnabled)

      if parsed.command == .metrics {
        if parsed.watchMetrics {
          try streamMetrics(to: parsed.socketPath, context: context)
        } else {
          let snapshot = try fetchMetricsSnapshot(from: parsed.socketPath, context: context)
          CLIOutput.printMetricsSnapshot(snapshot)
        }
      } else {
        try sendCommand(parsed.command, to: parsed.socketPath, context: context)
      }

      return 0
    } catch AppError.showUsage {
      CLIOutput.printUsage()
      return 1
    } catch AppError.showVersion {
      CLIOutput.printVersion()
      return 0
    } catch AppError.message(let message) {
      CLIOutput.printError(message)
    } catch {
      CLIOutput.printError("\(error)")
    }

    CLIOutput.printUsage()
    return 1
  }
}

private struct CLIOption {
  let flag: String
  let short: String?
  let command: IPC.Command?
  let description: String
  let placeholder: String?

  init(
    flag: String,
    short: String? = nil,
    command: IPC.Command? = nil,
    description: String,
    placeholder: String? = nil
  ) {
    self.flag = flag
    self.short = short
    self.command = command
    self.description = description
    self.placeholder = placeholder
  }
}

private struct ParsedArguments {
  let command: IPC.Command
  let socketPath: String
  let debugEnabled: Bool
  let watchMetrics: Bool
}

private struct AppContext {
  private let logger: ProcessLogger

  init(debugEnabled: Bool) {
    let envEnabled = boolEnvironmentValue(named: "EASYBAR_DEBUG") ?? false
    logger = ProcessLogger(
      label: "easybarctl", minimumLevel: (debugEnabled || envEnabled) ? .debug : .info)
  }

  /// Writes one debug line when CLI debug logging is enabled.
  func debug(_ message: String) {
    logger.debug(message)
  }
}

private enum AppError: Error {
  case showUsage
  case showVersion
  case message(String)
}

private enum CLIOutput {
  /// Writes one plain error line.
  static func printError(_ message: String) {
    fputs("easybar: \(message)\n", stderr)
  }

  /// Writes one plain version line.
  static func printVersion() {
    fputs("easybar \(BuildInfo.appVersion)\n", stdout)
  }

  /// Writes usage text.
  static func printUsage() {
    let commandLines = CLI.cmdOptions.map {
      CLI.formatOption(CLI.optionText(for: $0), $0.description)
    }
    let appOptionLines = CLI.appOptions.map {
      CLI.formatOption(CLI.optionText(for: $0), $0.description)
    }

    let lines: [String] =
      [
        "usage:",
        "  easybar <command> [options]",
        "",
        "commands:",
      ] + commandLines + [
        "",
        "options:",
      ] + appOptionLines

    fputs(lines.joined(separator: "\n") + "\n", stderr)
  }

  /// Writes one one-shot metrics snapshot.
  static func printMetricsSnapshot(_ snapshot: IPC.MetricsSnapshot) {
    fputs(MetricsRenderer.snapshotText(snapshot) + "\n", stdout)
  }
}

private enum CLI {
  static let socketOption = CLIOption(
    flag: "--socket",
    short: "-s",
    description: "Override socket path",
    placeholder: "path"
  )
  static let debugOption = CLIOption(
    flag: "--debug",
    short: "-d",
    description: "Enable debug output"
  )
  static let versionOption = CLIOption(
    flag: "--version",
    short: "-v",
    description: "Show the easybar version"
  )
  static let helpOption = CLIOption(
    flag: "--help",
    short: "-h",
    description: "Show this help"
  )
  static let watchOption = CLIOption(
    flag: "--watch",
    short: "-w",
    description: "Keep streaming metrics and render rolling graphs"
  )

  static let cmdOptions: [CLIOption] = [
    .init(
      flag: "--workspace-changed",
      command: .workspaceChanged,
      description: "Notify EasyBar that the focused workspace changed"
    ),
    .init(
      flag: "--focus-changed",
      command: .focusChanged,
      description: "Notify EasyBar that the focused app or window changed"
    ),
    .init(
      flag: "--space-mode-changed",
      command: .spaceModeChanged,
      description: "Notify EasyBar that the AeroSpace layout mode changed"
    ),
    .init(
      flag: "--refresh",
      command: .manualRefresh,
      description:
        "Refresh the bar and widgets using the currently loaded config and pull fresh data from agents"
    ),
    .init(
      flag: "--reload-config",
      command: .reloadConfig,
      description: "Reload config from disk and rebuild EasyBar with the new settings"
    ),
    .init(
      flag: "--restart-lua-runtime",
      command: .restartLuaRuntime,
      description: "Restart only the Lua widget runtime using the currently loaded config"
    ),
    .init(
      flag: "--metrics",
      command: .metrics,
      description: "Print a metrics snapshot or stream live metrics with --watch"
    ),
  ]

  static let appOptions: [CLIOption] = [
    socketOption,
    watchOption,
    debugOption,
    versionOption,
    helpOption,
  ]

  /// Formats one help row with aligned option text.
  static func formatOption(_ option: String, _ description: String) -> String {
    "  " + option.padding(toLength: 26, withPad: " ", startingAt: 0) + description
  }

  /// Returns the rendered text for one option, including short flag and placeholder.
  static func optionText(for option: CLIOption) -> String {
    var text = option.flag

    if let short = option.short {
      text += ", \(short)"
    }

    if let placeholder = option.placeholder {
      text += " <\(placeholder)>"
    }

    return text
  }

  /// Returns whether one argument matches an option's long or short flag.
  static func matches(_ option: CLIOption, argument: String) -> Bool {
    option.flag == argument || option.short == argument
  }

  /// Returns the inline `--flag=value` payload when present.
  static func inlineValue(for option: CLIOption, argument: String) -> String? {
    let prefix = "\(option.flag)="
    guard argument.hasPrefix(prefix) else { return nil }
    return String(argument.dropFirst(prefix.count))
  }

  /// Returns the command string associated with one argument when it is a command option.
  static func command(for argument: String) -> IPC.Command? {
    cmdOptions.first { matches($0, argument: argument) }?.command
  }
}

/// Parses CLI arguments into one validated command request.
private func parseArguments(_ arguments: [String]) throws -> ParsedArguments {
  var selectedCommand: IPC.Command?
  var socketPath = SharedRuntimeConfig.current.easyBarSocketPath
  var debugEnabled = false
  var watchMetrics = false

  var i = 1
  while i < arguments.count {
    let arg = arguments[i]

    if let nextIndex = try parseAppArgument(
      arg,
      arguments: arguments,
      index: i,
      socketPath: &socketPath,
      debugEnabled: &debugEnabled,
      watchMetrics: &watchMetrics
    ) {
      i = nextIndex
      continue
    }

    if let command = CLI.command(for: arg) {
      guard selectedCommand == nil else {
        throw AppError.message("only one command flag may be specified")
      }

      selectedCommand = command
      i += 1
      continue
    }

    throw AppError.message("unknown argument '\(arg)'")
  }

  guard let command = selectedCommand else {
    throw AppError.message("no command flag provided")
  }

  if watchMetrics && command != .metrics {
    throw AppError.message("--watch may only be used with --metrics")
  }

  return ParsedArguments(
    command: command,
    socketPath: socketPath,
    debugEnabled: debugEnabled,
    watchMetrics: watchMetrics
  )
}

/// Handles one app-level argument and returns the next parse index when matched.
private func parseAppArgument(
  _ argument: String,
  arguments: [String],
  index: Int,
  socketPath: inout String,
  debugEnabled: inout Bool,
  watchMetrics: inout Bool
) throws -> Int? {
  if CLI.matches(CLI.helpOption, argument: argument) {
    throw AppError.showUsage
  }

  if CLI.matches(CLI.versionOption, argument: argument) {
    throw AppError.showVersion
  }

  if CLI.matches(CLI.debugOption, argument: argument) {
    debugEnabled = true
    return index + 1
  }

  if CLI.matches(CLI.watchOption, argument: argument) {
    watchMetrics = true
    return index + 1
  }

  if let parsedSocketArgument = try parseSocketArgument(
    argument,
    arguments: arguments,
    index: index
  ) {
    socketPath = parsedSocketArgument.socketPath
    return parsedSocketArgument.nextIndex
  }

  return nil
}

/// Parses one socket option and returns the resolved value plus next index.
private func parseSocketArgument(
  _ argument: String,
  arguments: [String],
  index: Int
) throws -> (socketPath: String, nextIndex: Int)? {
  if let value = CLI.inlineValue(for: CLI.socketOption, argument: argument) {
    guard !value.isEmpty else {
      throw AppError.message("missing value for \(CLI.socketOption.flag)")
    }

    return (value, index + 1)
  }

  guard CLI.matches(CLI.socketOption, argument: argument) else {
    return nil
  }

  let nextIndex = index + 1
  guard nextIndex < arguments.count else {
    throw AppError.message("missing value for \(argument)")
  }

  let socketPath = arguments[nextIndex]
  guard !socketPath.isEmpty else {
    throw AppError.message("missing value for \(argument)")
  }

  return (socketPath, nextIndex + 1)
}

/// Connects to the EasyBar socket and sends one IPC command.
private func sendCommand(_ command: IPC.Command, to socketPath: String, context: AppContext) throws
{
  context.debug("sending command '\(command.rawValue)' to \(socketPath)")

  let transport = LineSocketClientTransport<IPC.Request, IPC.Message>(socketPath: socketPath)
  let response = try transport.send(request: IPC.Request(command: command))

  context.debug(
    "decoded response kind='\(response.kind.rawValue)' message='\(response.message ?? "<nil>")'"
  )

  guard response.kind == .accepted else {
    throw AppError.message(response.message ?? "command rejected")
  }

  context.debug("command sent")
}

/// Requests one one-shot metrics snapshot.
private func fetchMetricsSnapshot(from socketPath: String, context: AppContext) throws
  -> IPC.MetricsSnapshot
{
  context.debug("requesting metrics snapshot from \(socketPath)")

  let transport = LineSocketClientTransport<IPC.Request, IPC.Message>(socketPath: socketPath)
  let response = try transport.send(request: IPC.Request(command: .metrics))

  guard response.kind == .metrics, let metrics = response.metrics else {
    throw AppError.message(response.message ?? "metrics unavailable")
  }

  return metrics
}

/// Streams live metrics and renders them as a rolling terminal dashboard.
private func streamMetrics(to socketPath: String, context: AppContext) throws {
  let client = MetricsStreamClient(socketPath: socketPath)
  var history = MetricsHistory(limit: 32)
  let terminal = WatchTerminal()
  terminal.activate()
  defer { terminal.restore() }

  try client.stream(request: IPC.Request(command: .metrics, watch: true)) { message in
    guard message.kind == .metrics, let snapshot = message.metrics else {
      if message.kind == .rejected {
        throw AppError.message(message.message ?? "metrics rejected")
      }
      return
    }

    history.append(snapshot)
    CLIOutput.renderWatch(MetricsRenderer.watchText(snapshot, history: history), terminal: terminal)
  }

  context.debug("metrics stream ended")
}

extension CLIOutput {
  /// Clears the terminal and renders one live metrics frame.
  static func renderWatch(_ contents: String, terminal: WatchTerminal) {
    fputs(terminal.redrawPrefix + contents, stdout)
    fflush(stdout)
  }
}

/// Manages terminal state for live watch rendering.
private final class WatchTerminal {
  private let interactive: Bool = isatty(STDOUT_FILENO) != 0
  private var activated = false

  var redrawPrefix: String {
    interactive ? "\u{001B}[H\u{001B}[2J\u{001B}[3J" : ""
  }

  func activate() {
    guard interactive, !activated else { return }
    activated = true
    fputs("\u{001B}[?1049h\u{001B}[?25l\u{001B}[H\u{001B}[2J\u{001B}[3J", stdout)
    fflush(stdout)
  }

  func restore() {
    guard interactive, activated else { return }
    activated = false
    fputs("\u{001B}[?25h\u{001B}[?1049l", stdout)
    fflush(stdout)
  }
}

/// Maintains a small rolling window used for watch-mode graphs.
private struct MetricsHistory {
  let limit: Int
  private(set) var series: [String: [Double]] = [:]

  mutating func append(_ snapshot: IPC.MetricsSnapshot) {
    append(snapshot.process.cpuPercent ?? 0, for: "process.cpu")
    append(snapshot.lua.cpuPercent ?? 0, for: "lua.cpu")
    append(snapshot.runtime.eventsPerSecond, for: "runtime.events")
    append(snapshot.runtime.treeUpdatesPerSecond, for: "runtime.tree")
  }

  func values(for key: String) -> [Double] {
    series[key] ?? []
  }

  private mutating func append(_ value: Double, for key: String) {
    var values = series[key] ?? []
    values.append(max(0, value))

    if values.count > limit {
      values.removeFirst(values.count - limit)
    }

    series[key] = values
  }
}

/// Renders human-readable metrics text for one-shot and watch output.
private enum MetricsRenderer {
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

  private static func header(_ snapshot: IPC.MetricsSnapshot, live: Bool) -> String {
    let mode = live ? "live" : "snapshot"
    return "EasyBar metrics (\(mode))  \(timestamp(snapshot.timestamp))"
  }

  private static func graphs(_ snapshot: IPC.MetricsSnapshot, history: MetricsHistory) -> String {
    let lines = [
      row([
        column("metric", width: 10),
        column("now", width: 8, alignment: .right),
        column("avg", width: 8, alignment: .right),
        "history",
      ]),
      graphLine(
        label: "app cpu",
        current: percent(snapshot.process.cpuPercent),
        average: percent(average(history.values(for: "process.cpu"))),
        values: history.values(for: "process.cpu"),
        absoluteMax: 100
      ),
      graphLine(
        label: "lua cpu",
        current: percent(snapshot.lua.cpuPercent),
        average: percent(average(history.values(for: "lua.cpu"))),
        values: history.values(for: "lua.cpu"),
        absoluteMax: 100
      ),
      graphLine(
        label: "events/s",
        current: number(snapshot.runtime.eventsPerSecond),
        average: number(average(history.values(for: "runtime.events"))),
        values: history.values(for: "runtime.events")
      ),
      graphLine(
        label: "tree/s",
        current: number(snapshot.runtime.treeUpdatesPerSecond),
        average: number(average(history.values(for: "runtime.tree"))),
        values: history.values(for: "runtime.tree")
      ),
    ]

    return (["Graphs"] + lines).joined(separator: "\n")
  }

  private static func processes(_ snapshot: IPC.MetricsSnapshot) -> String {
    let lines = [
      "Processes",
      processHeader(),
      processLine(snapshot.process),
      processLine(snapshot.lua),
    ]
    return lines.joined(separator: "\n")
  }

  private static func runtime(_ snapshot: IPC.MetricsSnapshot) -> String {
    let runtime = snapshot.runtime

    return [
      "Runtime",
      row([
        column("metric", width: 18),
        column("value", width: 16),
        column("metric", width: 18),
        column("value", width: 16),
      ]),
      row([
        column("subscribers", width: 18),
        column(String(runtime.subscriberCount), width: 16),
        column("lua_ready", width: 18),
        column(yesNo(runtime.luaReady), width: 16),
      ]),
      row([
        column("subscribed_events", width: 18),
        column(String(runtime.subscribedEventCount), width: 16),
        column("lua_restarts", width: 18),
        column(String(runtime.luaRestartCount), width: 16),
      ]),
      row([
        column("events", width: 18),
        column("\(runtime.totalEvents) (\(number(runtime.eventsPerSecond))/s)", width: 16),
        column("tree_updates", width: 18),
        column("\(runtime.treeUpdates) (\(number(runtime.treeUpdatesPerSecond))/s)", width: 16),
      ]),
      row([
        column("stdout", width: 18),
        column(String(runtime.stdoutLines), width: 16),
        column("stderr", width: 18),
        column(String(runtime.stderrLines), width: 16),
      ]),
      row([
        column("lua_writes", width: 18),
        column(String(runtime.luaWrites), width: 16),
        column("decode_errors", width: 18),
        column(String(runtime.decodeErrors), width: 16),
      ]),
      row([
        column("last_tree", width: 18),
        column(runtime.lastTreeRoot ?? "-", width: 16),
        column("nodes", width: 18),
        column(runtime.lastTreeNodeCount.map(String.init) ?? "-", width: 16),
      ]),
    ].joined(separator: "\n")
  }

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

  private static func events(_ snapshot: IPC.MetricsSnapshot) -> String {
    guard !snapshot.events.isEmpty else {
      return "Events\nnone"
    }

    let header = row([
      column("name", width: 18),
      column("total", width: 6),
      column("rate", width: 10),
    ])

    let body = snapshot.events.map { event in
      row([
        column(event.name, width: 18),
        column(String(event.total), width: 6),
        column("\(number(event.perSecond))/s", width: 10),
      ])
    }

    return (["Events", header] + body).joined(separator: "\n")
  }

  private static func processHeader() -> String {
    row([
      column("name", width: 10),
      column("pid", width: 7),
      column("cpu", width: 8),
      column("mem", width: 10),
      column("thr", width: 5),
    ])
  }

  private static func processLine(_ process: IPC.ProcessMetrics) -> String {
    row([
      column(process.name, width: 10),
      column(process.pid.map(String.init) ?? "-", width: 7),
      column(percent(process.cpuPercent), width: 8),
      column(bytes(process.residentSizeBytes), width: 10),
      column(process.threadCount.map(String.init) ?? "-", width: 5),
    ])
  }

  private static func graphLine(
    label: String,
    current: String,
    average: String,
    values: [Double],
    absoluteMax: Double? = nil
  ) -> String {
    row([
      column(label, width: 10),
      column(current, width: 8, alignment: .right),
      column(average, width: 8, alignment: .right),
      sparkline(values, absoluteMax: absoluteMax),
    ])
  }

  private static func sparkline(_ values: [Double], absoluteMax: Double? = nil) -> String {
    guard !values.isEmpty else { return "[no data]" }

    let symbols = Array("▁▂▃▄▅▆▇█")
    let maxValue = absoluteMax ?? (values.max() ?? 0)

    guard maxValue > 0 else {
      return "[" + String(repeating: String(symbols[0]), count: values.count) + "]"
    }

    let rendered = values.map { value -> Character in
      let normalized = min(max(value / maxValue, 0), 1)
      let index = Int((normalized * Double(symbols.count - 1)).rounded())
      return symbols[index]
    }

    return "[" + String(rendered) + "]"
  }

  private static func timestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.string(from: date)
  }

  private static func relative(_ date: Date?) -> String {
    guard let date else { return "-" }

    let delta = max(0, Int(Date().timeIntervalSince(date)))
    return "\(delta)s"
  }

  private static func yesNo(_ value: Bool) -> String {
    value ? "yes" : "no"
  }

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

  private static func bytes(_ value: UInt64?) -> String {
    guard let value else { return "-" }

    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .memory
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: Int64(value))
  }

  private static func average(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    return values.reduce(0, +) / Double(values.count)
  }

  private static func row(_ columns: [String]) -> String {
    columns.joined(separator: "  ")
  }

  private enum ColumnAlignment {
    case left
    case right
  }

  private static func column(_ value: String, width: Int, alignment: ColumnAlignment = .left) -> String {
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

/// One streaming socket client used by `easybar --metrics --watch`.
private struct MetricsStreamClient {
  let socketPath: String

  func stream(
    request: IPC.Request,
    handleMessage: (IPC.Message) throws -> Void
  ) throws {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      throw LineSocketClientTransportError.socketFailed
    }

    defer { close(fd) }

    guard configureNoSigPipe(fd: fd) else {
      throw LineSocketClientTransportError.connectFailed("failed to configure socket no-sigpipe")
    }

    var addr = makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let connectResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, addrLen)
      }
    }

    guard connectResult == 0 else {
      throw LineSocketClientTransportError.connectFailed(String(cString: strerror(errno)))
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    guard let payload = try? encoder.encode(request) else {
      throw LineSocketClientTransportError.encodeFailed
    }

    try sendAll(fd: fd, data: payload + Data([0x0A]))

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var pending = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)

    while true {
      if let line = nextLine(from: &pending) {
        let message = try decoder.decode(IPC.Message.self, from: line)
        try handleMessage(message)
        continue
      }

      let count = read(fd, &buffer, buffer.count)

      if count > 0 {
        pending.append(contentsOf: buffer.prefix(count))
        continue
      }

      if count == 0 {
        return
      }

      if errno == EINTR {
        continue
      }

      throw LineSocketClientTransportError.connectFailed(String(cString: strerror(errno)))
    }
  }

  private func sendAll(fd: Int32, data: Data) throws {
    try data.withUnsafeBytes { rawBuffer in
      guard let base = rawBuffer.baseAddress else { return }

      var sent = 0
      while sent < data.count {
        let written = write(fd, base.advanced(by: sent), data.count - sent)

        if written <= 0 {
          if errno == EINTR {
            continue
          }

          throw LineSocketClientTransportError.writeFailed(String(cString: strerror(errno)))
        }

        sent += written
      }
    }
  }

  private func nextLine(from pending: inout Data) -> Data? {
    guard let newlineIndex = pending.firstIndex(of: 0x0A) else {
      return nil
    }

    let line = Data(pending.prefix(upTo: newlineIndex))
    pending.removeSubrange(...newlineIndex)
    return line.isEmpty ? nil : line
  }
}
