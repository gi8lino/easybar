import EasyBarShared
import Foundation

/// Collects lightweight runtime metrics and streams coalesced snapshots on demand.
actor MetricsCoordinator {
  /// Callback invoked for streamed snapshots.
  typealias SnapshotHandler = (IPC.MetricsSnapshot) -> Void

  /// Helper agent tracked by metrics.
  enum AgentKey: String, CaseIterable {
    case calendar
    case network

    /// Name shown in metrics output.
    var displayName: String {
      switch self {
      case .calendar:
        return "calendar"
      case .network:
        return "network"
      }
    }

    /// Bundle identifier for the helper app.
    var bundleIdentifier: String {
      switch self {
      case .calendar:
        return "com.gi8lino.EasyBarCalendarAgent"
      case .network:
        return "com.gi8lino.EasyBarNetworkAgent"
      }
    }

    /// Process name used for sampling.
    var processName: String {
      switch self {
      case .calendar:
        return "EasyBarCalendarAgent"
      case .network:
        return "EasyBarNetworkAgent"
      }
    }
  }

  /// Mutable counters for one helper agent.
  private struct AgentState {
    /// Number of active socket connections.
    var activeConnections = 0
    /// Whether the agent has connected at least once.
    var everConnected = false
    /// Total decoded messages.
    var messagesTotal = 0
    /// Total reconnects after the first connection.
    var reconnectsTotal = 0
    /// Total refresh requests.
    var refreshesTotal = 0
    /// Total decode failures.
    var decodeErrorsTotal = 0
    /// Timestamp of the last decoded message.
    var lastMessageAt: Date?
    /// Timestamp of the last disconnect.
    var lastDisconnectAt: Date?

    /// Records a new active connection and counts reconnects after the first connection.
    mutating func recordConnection() {
      if activeConnections == 0 && everConnected {
        reconnectsTotal += 1
      }

      activeConnections += 1
      everConnected = true
    }

    /// Records one closed connection without allowing the active count to go negative.
    mutating func recordDisconnect(at date: Date) {
      activeConnections = max(0, activeConnections - 1)
      lastDisconnectAt = date
    }
  }

  /// Counter snapshot used to compute rates.
  private struct SampleCounters {
    var totalEvents: Int
    var droppedEvents: Int
    var coalescedEvents: Int
    var treeUpdates: Int
    var transportLines: Int
    var stderrLines: Int
    var luaWrites: Int
    var agentMessages: [AgentKey: Int]
    var widgetUpdates: [String: Int]
    var eventCounts: [String: Int]
    var droppedEventCounts: [String: Int]
    var coalescedEventCounts: [String: Int]
  }

  /// Inputs needed to compute per-second rates.
  private struct RateContext {
    let baseline: SampleCounters?
    let interval: TimeInterval
    let collectionEnabled: Bool
  }

  /// Process samples included in one metrics snapshot.
  private struct ProcessSamples {
    let app: IPC.ProcessMetrics
    let lua: IPC.ProcessMetrics
    let calendar: IPC.ProcessMetrics
    let network: IPC.ProcessMetrics
  }

  /// Actor-isolated mutable metrics state.
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
    var droppedEvents = 0
    var coalescedEvents = 0
    var droppedEventCounts: [String: Int] = [:]
    var coalescedEventCounts: [String: Int] = [:]

    var transportLines = 0
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

    /// Returns whether at least one metrics stream subscriber is active.
    var hasStreamingSubscribers: Bool {
      !streamingSubscriberFDs.isEmpty
    }

    /// Adds one stream subscriber and returns whether sampling should start.
    mutating func addStreamingSubscriber(fd: Int32) -> Bool {
      let wasEmpty = streamingSubscriberFDs.isEmpty
      let inserted = streamingSubscriberFDs.insert(fd).inserted
      return inserted && wasEmpty
    }

    /// Removes one stream subscriber and returns whether sampling should stop.
    mutating func removeStreamingSubscriber(fd: Int32) -> Bool {
      guard streamingSubscriberFDs.remove(fd) != nil else {
        return false
      }

      return streamingSubscriberFDs.isEmpty
    }

    /// Removes all stream subscribers.
    mutating func removeAllStreamingSubscribers() {
      streamingSubscriberFDs.removeAll()
    }
  }

  /// Shared process-wide metrics coordinator.
  static var shared = MetricsCoordinator()

  /// Metrics sampling interval.
  private let sampleIntervalSeconds: TimeInterval = 1
  /// Metrics sampling interval in nanoseconds.
  private let sampleIntervalNanoseconds: UInt64 = 1_000_000_000
  /// Process sampler for EasyBar, Lua, and agents.
  private let processSampler = ProcessSampler()

  /// Current actor-isolated metrics state.
  private var state = State()
  /// Periodic streaming task.
  private var streamingTask: Task<Void, Never>?
  /// Callback invoked for streamed snapshots.
  private var onSnapshot: SnapshotHandler?

  init() {}

  /// Returns whether metrics streaming is currently active.
  var isStreamingActive: Bool {
    return state.hasStreamingSubscribers
  }

  /// Installs the callback invoked for streamed snapshots.
  func setSnapshotHandler(_ handler: SnapshotHandler?) {
    onSnapshot = handler
  }

  /// Starts streaming collection for one subscriber.
  func addStreamingSubscriber(fd: Int32) {
    if state.addStreamingSubscriber(fd: fd) {
      startStreamingTask()
    }
  }

  /// Stops streaming collection for one subscriber.
  func removeStreamingSubscriber(fd: Int32) {
    if state.removeStreamingSubscriber(fd: fd) {
      stopStreamingTask()
    }
  }

  /// Stops all streaming subscribers and sampling.
  func resetStreaming() {
    state.removeAllStreamingSubscribers()
    stopStreamingTask()
  }

  /// Builds one point-in-time snapshot.
  func snapshot() -> IPC.MetricsSnapshot {
    return collectSnapshot(collectionEnabled: isStreamingActive)
  }

  /// Records one emitted event.
  func recordEvent(name: String, isWidgetEvent: Bool) {
    state.totalEvents += 1
    if isWidgetEvent {
      state.widgetEvents += 1
    } else {
      state.appEvents += 1
    }
    state.eventCounts[name, default: 0] += 1
  }

  /// Records one event dropped or coalesced because a subscriber buffer was full.
  func recordEventBackpressure(name: String, coalesced: Bool) {
    if coalesced {
      state.coalescedEvents += 1
      state.coalescedEventCounts[name, default: 0] += 1
    } else {
      state.droppedEvents += 1
      state.droppedEventCounts[name, default: 0] += 1
    }
  }

  /// Records one line written to the Lua transport socket.
  func recordLuaWrite() {
    state.luaWrites += 1
  }

  /// Records one line read from the Lua transport socket.
  func recordLuaTransportLine() {
    state.transportLines += 1
  }

  /// Records one line read from Lua stderr.
  func recordLuaStderrLine() {
    state.stderrLines += 1
  }

  /// Records one runtime decode failure.
  func recordDecodeError() {
    state.decodeErrors += 1
  }

  /// Records the Lua runtime starting with a new PID.
  func recordLuaRuntimeStarted(pid: Int32) {
    if state.hasSeenLuaStart {
      state.luaRestartCount += 1
    }
    state.hasSeenLuaStart = true
    state.luaPID = pid
    state.luaReady = false
  }

  /// Records the Lua runtime stopping.
  func recordLuaRuntimeStopped() {
    let pid = state.luaPID
    state.luaPID = nil
    state.luaReady = false
    state.subscribedEvents.removeAll()

    processSampler.clear(pid: pid)
  }

  /// Records the Lua runtime ready handshake.
  func recordLuaReady() {
    state.luaReady = true
  }

  /// Records the subscribed runtime event set.
  func recordLuaSubscriptions(_ events: Set<String>) {
    state.subscribedEvents = events
  }

  /// Records one widget tree update.
  func recordTreeUpdate(root: String, nodeCount: Int, at date: Date = Date()) {
    state.treeUpdates += 1
    state.lastTreeRoot = root
    state.lastTreeNodeCount = nodeCount
    state.lastTreeAt = date
    state.widgetUpdateCounts[root, default: 0] += 1
    state.widgetNodeCounts[root] = nodeCount
    state.widgetLastUpdatedAt[root] = date
  }

  /// Records one agent connection.
  func recordAgentConnected(_ agent: AgentKey) {
    var agentState = state.agents[agent] ?? AgentState()
    agentState.recordConnection()
    state.agents[agent] = agentState
  }

  /// Records one agent disconnect.
  func recordAgentDisconnected(_ agent: AgentKey, at date: Date = Date()) {
    var agentState = state.agents[agent] ?? AgentState()
    agentState.recordDisconnect(at: date)
    state.agents[agent] = agentState
  }

  /// Records one agent refresh request.
  func recordAgentRefresh(_ agent: AgentKey) {
    var agentState = state.agents[agent] ?? AgentState()
    agentState.refreshesTotal += 1
    state.agents[agent] = agentState
  }

  /// Records one decoded agent message.
  func recordAgentMessage(_ agent: AgentKey, at date: Date = Date()) {
    var agentState = state.agents[agent] ?? AgentState()
    agentState.messagesTotal += 1
    agentState.lastMessageAt = date
    state.agents[agent] = agentState
  }

  /// Records one agent decode failure.
  func recordAgentDecodeError(_ agent: AgentKey) {
    var agentState = state.agents[agent] ?? AgentState()
    agentState.decodeErrorsTotal += 1
    state.agents[agent] = agentState
  }

  /// Starts periodic metrics sampling.
  private func startStreamingTask() {
    guard streamingTask == nil else { return }

    let intervalNanoseconds = sampleIntervalNanoseconds

    streamingTask = Task { [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(nanoseconds: intervalNanoseconds)
        } catch {
          break
        }

        guard !Task.isCancelled else { break }
        await self?.collectAndPublishStreamingSnapshot()
      }
    }
  }

  /// Stops periodic metrics sampling.
  private func stopStreamingTask() {
    streamingTask?.cancel()
    streamingTask = nil
    state.previousCounters = nil
    state.lastSampleAt = nil
  }

  /// Collects and publishes one streaming snapshot when subscribers are still active.
  private func collectAndPublishStreamingSnapshot() {
    guard state.hasStreamingSubscribers else {
      stopStreamingTask()
      return
    }

    let snapshot = collectSnapshot(collectionEnabled: true)
    onSnapshot?(snapshot)
  }

  /// Collects one metrics snapshot and updates rate baselines when enabled.
  private func collectSnapshot(collectionEnabled: Bool) -> IPC.MetricsSnapshot {
    let now = Date()
    let snapshotState = state

    let previousSampleAt = snapshotState.lastSampleAt
    let interval = previousSampleAt.map { now.timeIntervalSince($0) } ?? sampleIntervalSeconds
    let safeInterval = interval > 0 ? interval : sampleIntervalSeconds
    let rateContext = RateContext(
      baseline: snapshotState.previousCounters,
      interval: safeInterval,
      collectionEnabled: collectionEnabled
    )
    let processSamples = sampleProcesses(from: snapshotState, now: now)
    let currentCounters = sampleCounters(from: snapshotState)

    let snapshot = IPC.MetricsSnapshot(
      timestamp: now,
      collectionEnabled: collectionEnabled,
      sampleIntervalSeconds: sampleIntervalSeconds,
      process: processSamples.app,
      lua: processSamples.lua,
      runtime: runtimeMetrics(from: snapshotState, rateContext: rateContext),
      agents: agentMetrics(
        from: snapshotState,
        processSamples: processSamples,
        rateContext: rateContext
      ),
      widgets: widgetMetrics(from: snapshotState, rateContext: rateContext),
      events: eventMetrics(from: snapshotState, rateContext: rateContext)
    )

    if collectionEnabled {
      state.previousCounters = currentCounters
      state.lastSampleAt = now
    }

    return snapshot
  }

  /// Samples EasyBar, Lua, and helper agent processes.
  private func sampleProcesses(from snapshotState: State, now: Date) -> ProcessSamples {
    return ProcessSamples(
      app: processSampler.sampleCurrentProcess(named: "EasyBar", now: now),
      lua: processSampler.sampleProcess(named: "lua", pid: snapshotState.luaPID, now: now),
      calendar: processSampler.sampleProcessNamed(
        named: AgentKey.calendar.processName,
        executableName: AgentKey.calendar.processName,
        now: now
      ),
      network: processSampler.sampleProcessNamed(
        named: AgentKey.network.processName,
        executableName: AgentKey.network.processName,
        now: now
      )
    )
  }

  /// Captures cumulative counters for the next streaming-rate baseline.
  private func sampleCounters(from snapshotState: State) -> SampleCounters {
    return SampleCounters(
      totalEvents: snapshotState.totalEvents,
      droppedEvents: snapshotState.droppedEvents,
      coalescedEvents: snapshotState.coalescedEvents,
      treeUpdates: snapshotState.treeUpdates,
      transportLines: snapshotState.transportLines,
      stderrLines: snapshotState.stderrLines,
      luaWrites: snapshotState.luaWrites,
      agentMessages: AgentKey.allCases.reduce(into: [:]) { result, key in
        result[key] = snapshotState.agents[key]?.messagesTotal ?? 0
      },
      widgetUpdates: snapshotState.widgetUpdateCounts,
      eventCounts: snapshotState.eventCounts,
      droppedEventCounts: snapshotState.droppedEventCounts,
      coalescedEventCounts: snapshotState.coalescedEventCounts
    )
  }

  /// Builds runtime counters for one snapshot.
  private func runtimeMetrics(
    from snapshotState: State,
    rateContext: RateContext
  ) -> IPC.RuntimeMetrics {
    let baseline = rateContext.baseline

    return IPC.RuntimeMetrics(
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
        context: rateContext
      ),
      droppedEvents: snapshotState.droppedEvents,
      droppedEventsPerSecond: rate(
        current: snapshotState.droppedEvents,
        previous: baseline?.droppedEvents,
        context: rateContext
      ),
      coalescedEvents: snapshotState.coalescedEvents,
      coalescedEventsPerSecond: rate(
        current: snapshotState.coalescedEvents,
        previous: baseline?.coalescedEvents,
        context: rateContext
      ),
      transportLines: snapshotState.transportLines,
      stderrLines: snapshotState.stderrLines,
      luaWrites: snapshotState.luaWrites,
      treeUpdates: snapshotState.treeUpdates,
      treeUpdatesPerSecond: rate(
        current: snapshotState.treeUpdates,
        previous: baseline?.treeUpdates,
        context: rateContext
      ),
      decodeErrors: snapshotState.decodeErrors,
      lastTreeRoot: snapshotState.lastTreeRoot,
      lastTreeNodeCount: snapshotState.lastTreeNodeCount,
      lastTreeAt: snapshotState.lastTreeAt
    )
  }

  /// Builds helper agent metrics for one snapshot.
  private func agentMetrics(
    from snapshotState: State,
    processSamples: ProcessSamples,
    rateContext: RateContext
  ) -> [IPC.AgentMetrics] {
    return AgentKey.allCases.map { key -> IPC.AgentMetrics in
      let agentState = snapshotState.agents[key] ?? AgentState()
      let processMetrics = key == .calendar ? processSamples.calendar : processSamples.network

      return IPC.AgentMetrics(
        name: key.displayName,
        connected: agentState.activeConnections > 0,
        process: processMetrics,
        messagesTotal: agentState.messagesTotal,
        messagesPerSecond: rate(
          current: agentState.messagesTotal,
          previous: rateContext.baseline?.agentMessages[key],
          context: rateContext
        ),
        reconnectsTotal: agentState.reconnectsTotal,
        refreshesTotal: agentState.refreshesTotal,
        decodeErrorsTotal: agentState.decodeErrorsTotal,
        lastMessageAt: agentState.lastMessageAt,
        lastDisconnectAt: agentState.lastDisconnectAt
      )
    }
  }

  /// Builds the highest-volume widget counters for one snapshot.
  private func widgetMetrics(
    from snapshotState: State,
    rateContext: RateContext
  ) -> [IPC.WidgetMetrics] {
    let widgets = snapshotState.widgetUpdateCounts
      .map { id, total in
        IPC.WidgetMetrics(
          id: id,
          updatesTotal: total,
          updatesPerSecond: rate(
            current: total,
            previous: rateContext.baseline?.widgetUpdates[id],
            context: rateContext
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

    return Array(widgets)
  }

  /// Builds the highest-volume event counters for one snapshot.
  private func eventMetrics(
    from snapshotState: State,
    rateContext: RateContext
  ) -> [IPC.CounterMetrics] {
    let counterNames = Set(snapshotState.eventCounts.keys)
      .union(snapshotState.droppedEventCounts.keys)
      .union(snapshotState.coalescedEventCounts.keys)

    let events =
      counterNames
      .map { name in
        IPC.CounterMetrics(
          name: name,
          total: snapshotState.eventCounts[name] ?? 0,
          perSecond: rate(
            current: snapshotState.eventCounts[name] ?? 0,
            previous: rateContext.baseline?.eventCounts[name],
            context: rateContext
          ),
          droppedTotal: snapshotState.droppedEventCounts[name] ?? 0,
          droppedPerSecond: rate(
            current: snapshotState.droppedEventCounts[name] ?? 0,
            previous: rateContext.baseline?.droppedEventCounts[name],
            context: rateContext
          ),
          coalescedTotal: snapshotState.coalescedEventCounts[name] ?? 0,
          coalescedPerSecond: rate(
            current: snapshotState.coalescedEventCounts[name] ?? 0,
            previous: rateContext.baseline?.coalescedEventCounts[name],
            context: rateContext
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

    return Array(events)
  }

  /// Computes a per-second rate from cumulative counters.
  private func rate(
    current: Int,
    previous: Int?,
    context: RateContext
  ) -> Double {
    guard context.collectionEnabled, let previous else { return 0 }
    guard context.interval > 0 else { return 0 }

    let delta = max(0, current - previous)
    return Double(delta) / context.interval
  }
}
