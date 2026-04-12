import EasyBarShared
import Foundation

/// Collects lightweight runtime metrics and streams coalesced snapshots on demand.
final class MetricsCoordinator {
  enum AgentKey: String, CaseIterable {
    case calendar
    case network

    var displayName: String {
      switch self {
      case .calendar:
        return "calendar"
      case .network:
        return "network"
      }
    }

    var bundleIdentifier: String {
      switch self {
      case .calendar:
        return "com.gi8lino.EasyBarCalendarAgent"
      case .network:
        return "com.gi8lino.EasyBarNetworkAgent"
      }
    }

    var processName: String {
      switch self {
      case .calendar:
        return "EasyBarCalendarAgent"
      case .network:
        return "EasyBarNetworkAgent"
      }
    }
  }

  private struct AgentState {
    var activeConnections = 0
    var everConnected = false
    var messagesTotal = 0
    var reconnectsTotal = 0
    var refreshesTotal = 0
    var decodeErrorsTotal = 0
    var lastMessageAt: Date?
    var lastDisconnectAt: Date?
  }

  private struct SampleCounters {
    var totalEvents: Int
    var treeUpdates: Int
    var stdoutLines: Int
    var stderrLines: Int
    var luaWrites: Int
    var agentMessages: [AgentKey: Int]
    var widgetUpdates: [String: Int]
    var eventCounts: [String: Int]
  }

  private struct State {
    var streamingSubscriberFDs = Set<Int32>()
    var luaPID: Int32?
    var hasSeenLuaStart = false
    var luaRestartCount = 0
    var luaReady = false
    var subscribedEvents = Set<String>()

    var totalEvents = 0
    var appEvents = 0
    var widgetEvents = 0
    var eventCounts: [String: Int] = [:]

    var stdoutLines = 0
    var stderrLines = 0
    var luaWrites = 0
    var decodeErrors = 0

    var treeUpdates = 0
    var lastTreeRoot: String?
    var lastTreeNodeCount: Int?
    var lastTreeAt: Date?
    var widgetUpdateCounts: [String: Int] = [:]
    var widgetNodeCounts: [String: Int] = [:]
    var widgetLastUpdatedAt: [String: Date] = [:]

    var agents: [AgentKey: AgentState] = Dictionary(
      uniqueKeysWithValues: AgentKey.allCases.map { ($0, AgentState()) })

    var previousCounters: SampleCounters?
    var lastSampleAt: Date?
  }

  static let shared = MetricsCoordinator()

  private let lock = NSLock()
  private let queue = DispatchQueue(label: "easybar.metrics", qos: .utility)
  private let sampleIntervalSeconds: TimeInterval = 1
  private let processSampler = ProcessSampler()

  private var state = State()
  private var timer: DispatchSourceTimer?

  var onSnapshot: ((IPC.MetricsSnapshot) -> Void)?

  private init() {}

  /// Returns whether metrics streaming is currently active.
  var isStreamingActive: Bool {
    withLock { !state.streamingSubscriberFDs.isEmpty }
  }

  /// Starts streaming collection for one subscriber.
  func addStreamingSubscriber(fd: Int32) {
    let shouldStart = withLock { () -> Bool in
      let inserted = state.streamingSubscriberFDs.insert(fd).inserted
      return inserted && state.streamingSubscriberFDs.count == 1
    }

    if shouldStart {
      startTimer()
    }
  }

  /// Stops streaming collection for one subscriber.
  func removeStreamingSubscriber(fd: Int32) {
    let shouldStop = withLock { () -> Bool in
      guard state.streamingSubscriberFDs.remove(fd) != nil else { return false }
      return state.streamingSubscriberFDs.isEmpty
    }

    if shouldStop {
      stopTimer()
    }
  }

  /// Stops all streaming subscribers and sampling.
  func resetStreaming() {
    withLock {
      state.streamingSubscriberFDs.removeAll()
    }
    stopTimer()
  }

  /// Builds one point-in-time snapshot.
  func snapshot() -> IPC.MetricsSnapshot {
    collectSnapshot(collectionEnabled: isStreamingActive)
  }

  /// Records one emitted event.
  func recordEvent(name: String, isWidgetEvent: Bool) {
    withLock {
      state.totalEvents += 1
      if isWidgetEvent {
        state.widgetEvents += 1
      } else {
        state.appEvents += 1
      }
      state.eventCounts[name, default: 0] += 1
    }
  }

  /// Records one line written to Lua stdin.
  func recordLuaWrite() {
    withLock { state.luaWrites += 1 }
  }

  /// Records one line read from Lua stdout.
  func recordLuaStdoutLine() {
    withLock { state.stdoutLines += 1 }
  }

  /// Records one line read from Lua stderr.
  func recordLuaStderrLine() {
    withLock { state.stderrLines += 1 }
  }

  /// Records one runtime decode failure.
  func recordDecodeError() {
    withLock { state.decodeErrors += 1 }
  }

  /// Records the Lua runtime starting with a new PID.
  func recordLuaRuntimeStarted(pid: Int32) {
    withLock {
      if state.hasSeenLuaStart {
        state.luaRestartCount += 1
      }
      state.hasSeenLuaStart = true
      state.luaPID = pid
      state.luaReady = false
    }
  }

  /// Records the Lua runtime stopping.
  func recordLuaRuntimeStopped() {
    let pid = withLock { () -> Int32? in
      let pid = state.luaPID
      state.luaPID = nil
      state.luaReady = false
      state.subscribedEvents.removeAll()
      return pid
    }

    processSampler.clear(pid: pid)
  }

  /// Records the Lua runtime ready handshake.
  func recordLuaReady() {
    withLock { state.luaReady = true }
  }

  /// Records the subscribed runtime event set.
  func recordLuaSubscriptions(_ events: Set<String>) {
    withLock { state.subscribedEvents = events }
  }

  /// Records one widget tree update.
  func recordTreeUpdate(root: String, nodeCount: Int, at date: Date = Date()) {
    withLock {
      state.treeUpdates += 1
      state.lastTreeRoot = root
      state.lastTreeNodeCount = nodeCount
      state.lastTreeAt = date
      state.widgetUpdateCounts[root, default: 0] += 1
      state.widgetNodeCounts[root] = nodeCount
      state.widgetLastUpdatedAt[root] = date
    }
  }

  /// Records one agent connection.
  func recordAgentConnected(_ agent: AgentKey) {
    withLock {
      var agentState = state.agents[agent] ?? AgentState()

      if agentState.activeConnections == 0 && agentState.everConnected {
        agentState.reconnectsTotal += 1
      }

      agentState.activeConnections += 1
      agentState.everConnected = true
      state.agents[agent] = agentState
    }
  }

  /// Records one agent disconnect.
  func recordAgentDisconnected(_ agent: AgentKey, at date: Date = Date()) {
    withLock {
      var agentState = state.agents[agent] ?? AgentState()
      agentState.activeConnections = max(0, agentState.activeConnections - 1)
      agentState.lastDisconnectAt = date
      state.agents[agent] = agentState
    }
  }

  /// Records one agent refresh request.
  func recordAgentRefresh(_ agent: AgentKey) {
    withLock {
      var agentState = state.agents[agent] ?? AgentState()
      agentState.refreshesTotal += 1
      state.agents[agent] = agentState
    }
  }

  /// Records one decoded agent message.
  func recordAgentMessage(_ agent: AgentKey, at date: Date = Date()) {
    withLock {
      var agentState = state.agents[agent] ?? AgentState()
      agentState.messagesTotal += 1
      agentState.lastMessageAt = date
      state.agents[agent] = agentState
    }
  }

  /// Records one agent decode failure.
  func recordAgentDecodeError(_ agent: AgentKey) {
    withLock {
      var agentState = state.agents[agent] ?? AgentState()
      agentState.decodeErrorsTotal += 1
      state.agents[agent] = agentState
    }
  }

  private func startTimer() {
    queue.async {
      guard self.timer == nil else { return }

      let timer = DispatchSource.makeTimerSource(queue: self.queue)
      timer.schedule(
        deadline: .now() + self.sampleIntervalSeconds, repeating: self.sampleIntervalSeconds)
      timer.setEventHandler { [weak self] in
        guard let self else { return }
        let snapshot = self.collectSnapshot(collectionEnabled: true)
        self.onSnapshot?(snapshot)
      }
      self.timer = timer
      timer.resume()
    }
  }

  private func stopTimer() {
    queue.async {
      self.timer?.cancel()
      self.timer = nil

      self.withLock {
        self.state.previousCounters = nil
        self.state.lastSampleAt = nil
      }
    }
  }

  private func collectSnapshot(collectionEnabled: Bool) -> IPC.MetricsSnapshot {
    let now = Date()

    let snapshotState = withLock { state }
    let appProcess = processSampler.sampleCurrentProcess(named: "EasyBar", now: now)
    let luaProcess = processSampler.sampleProcess(named: "lua", pid: snapshotState.luaPID, now: now)
    let calendarProcess = processSampler.sampleProcessNamed(
      named: AgentKey.calendar.processName,
      executableName: AgentKey.calendar.processName,
      now: now
    )
    let networkProcess = processSampler.sampleProcessNamed(
      named: AgentKey.network.processName,
      executableName: AgentKey.network.processName,
      now: now
    )

    let baseline = snapshotState.previousCounters
    let previousSampleAt = snapshotState.lastSampleAt
    let interval = previousSampleAt.map { now.timeIntervalSince($0) } ?? sampleIntervalSeconds
    let safeInterval = interval > 0 ? interval : sampleIntervalSeconds

    let currentCounters = SampleCounters(
      totalEvents: snapshotState.totalEvents,
      treeUpdates: snapshotState.treeUpdates,
      stdoutLines: snapshotState.stdoutLines,
      stderrLines: snapshotState.stderrLines,
      luaWrites: snapshotState.luaWrites,
      agentMessages: AgentKey.allCases.reduce(into: [:]) { result, key in
        result[key] = snapshotState.agents[key]?.messagesTotal ?? 0
      },
      widgetUpdates: snapshotState.widgetUpdateCounts,
      eventCounts: snapshotState.eventCounts
    )

    let runtime = IPC.RuntimeMetrics(
      subscriberCount: snapshotState.streamingSubscriberFDs.count,
      luaRestartCount: snapshotState.luaRestartCount,
      luaReady: snapshotState.luaReady,
      subscribedEventCount: snapshotState.subscribedEvents.count,
      totalEvents: snapshotState.totalEvents,
      appEvents: snapshotState.appEvents,
      widgetEvents: snapshotState.widgetEvents,
      eventsPerSecond: rate(
        current: snapshotState.totalEvents,
        previous: baseline?.totalEvents,
        interval: safeInterval,
        enabled: collectionEnabled
      ),
      stdoutLines: snapshotState.stdoutLines,
      stderrLines: snapshotState.stderrLines,
      luaWrites: snapshotState.luaWrites,
      treeUpdates: snapshotState.treeUpdates,
      treeUpdatesPerSecond: rate(
        current: snapshotState.treeUpdates,
        previous: baseline?.treeUpdates,
        interval: safeInterval,
        enabled: collectionEnabled
      ),
      decodeErrors: snapshotState.decodeErrors,
      lastTreeRoot: snapshotState.lastTreeRoot,
      lastTreeNodeCount: snapshotState.lastTreeNodeCount,
      lastTreeAt: snapshotState.lastTreeAt
    )

    let agents = AgentKey.allCases.map { key -> IPC.AgentMetrics in
      let agentState = snapshotState.agents[key] ?? AgentState()
      let processMetrics = key == .calendar ? calendarProcess : networkProcess

      return IPC.AgentMetrics(
        name: key.displayName,
        connected: agentState.activeConnections > 0,
        process: processMetrics,
        messagesTotal: agentState.messagesTotal,
        messagesPerSecond: rate(
          current: agentState.messagesTotal,
          previous: baseline?.agentMessages[key],
          interval: safeInterval,
          enabled: collectionEnabled
        ),
        reconnectsTotal: agentState.reconnectsTotal,
        refreshesTotal: agentState.refreshesTotal,
        decodeErrorsTotal: agentState.decodeErrorsTotal,
        lastMessageAt: agentState.lastMessageAt,
        lastDisconnectAt: agentState.lastDisconnectAt
      )
    }

    let widgets = snapshotState.widgetUpdateCounts
      .map { id, total in
        IPC.WidgetMetrics(
          id: id,
          updatesTotal: total,
          updatesPerSecond: rate(
            current: total,
            previous: baseline?.widgetUpdates[id],
            interval: safeInterval,
            enabled: collectionEnabled
          ),
          lastNodeCount: snapshotState.widgetNodeCounts[id] ?? 0,
          lastUpdatedAt: snapshotState.widgetLastUpdatedAt[id]
        )
      }
      .sorted { lhs, rhs in
        if lhs.updatesTotal != rhs.updatesTotal {
          return lhs.updatesTotal > rhs.updatesTotal
        }
        return lhs.id < rhs.id
      }
      .prefix(8)

    let events = snapshotState.eventCounts
      .map { name, total in
        IPC.CounterMetrics(
          name: name,
          total: total,
          perSecond: rate(
            current: total,
            previous: baseline?.eventCounts[name],
            interval: safeInterval,
            enabled: collectionEnabled
          )
        )
      }
      .sorted { lhs, rhs in
        if lhs.total != rhs.total {
          return lhs.total > rhs.total
        }
        return lhs.name < rhs.name
      }
      .prefix(8)

    let snapshot = IPC.MetricsSnapshot(
      timestamp: now,
      collectionEnabled: collectionEnabled,
      sampleIntervalSeconds: sampleIntervalSeconds,
      process: appProcess,
      lua: luaProcess,
      runtime: runtime,
      agents: Array(agents),
      widgets: Array(widgets),
      events: Array(events)
    )

    if collectionEnabled {
      withLock {
        state.previousCounters = currentCounters
        state.lastSampleAt = now
      }
    }

    return snapshot
  }

  private func rate(
    current: Int,
    previous: Int?,
    interval: TimeInterval,
    enabled: Bool
  ) -> Double {
    guard enabled, let previous else { return 0 }
    guard interval > 0 else { return 0 }

    let delta = max(0, current - previous)
    return Double(delta) / interval
  }

  private func withLock<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }
}
