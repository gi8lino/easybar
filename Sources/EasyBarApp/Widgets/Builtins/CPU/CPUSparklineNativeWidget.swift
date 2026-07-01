import Darwin.Mach
import Foundation

/// Native CPU widget that samples system usage and renders a sparkline.
@MainActor
final class CPUSparklineNativeWidget: NativeWidget {

  let rootID = "builtin_cpu"
  let widgetStore: WidgetStore

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.secondTick.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  private let config: Config.CPUBuiltinConfig
  private let eventObserver = EasyBarEventObserver()
  private var samples: [Double] = []
  private var previousCPUInfo: host_cpu_load_info_data_t?
  private var lastSampleDate: Date?
  private var isRunning = false

  private lazy var renderer = CPURenderer(rootID: rootID)

  /// Creates the native CPU widget from an immutable config section.
  init(config: Config.CPUBuiltinConfig, widgetStore: WidgetStore) {
    self.config = config
    self.widgetStore = widgetStore
  }

  /// Immutable render input for the CPU widget.
  struct Snapshot {
    let placement: Config.BuiltinWidgetPlacement
    let style: Config.BuiltinWidgetStyle
    let label: String
    let colorHex: String?
    let lineWidth: Double
    let samples: [Double]
  }

  /// Starts CPU sampling and publishes the initial widget state.
  func start() {
    guard !isRunning else { return }

    isRunning = true
    samples = Array(repeating: 0, count: historySize)
    previousCPUInfo = readCPUInfo()
    lastSampleDate = nil

    NativeWidgetEventDriver.start(
      observer: eventObserver,
      eventNames: appEventSubscriptions
    ) { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }

      switch event {
      case .secondTick:
        self.sampleAndPublishIfNeeded()

      case .systemWoke:
        // Reset the baseline because CPU tick counters can jump after wake.
        self.previousCPUInfo = self.readCPUInfo()
        self.lastSampleDate = nil
        self.publish()

      case .intervalTick:
        break

      default:
        break
      }
    }

    publish()
  }

  /// Stops CPU sampling and removes the rendered widget nodes.
  func stop() {
    guard isRunning else { return }

    isRunning = false
    eventObserver.stop()
    samples.removeAll()
    previousCPUInfo = nil
    lastSampleDate = nil

    clearNodes()
  }

  /// Reads one CPU sample when the configured interval has elapsed.
  private func sampleAndPublishIfNeeded() {
    let now = Date()

    guard shouldSample(at: now) else {
      return
    }

    sampleAndPublish(at: now)
  }

  /// Returns whether enough time has passed for the next CPU sample.
  private func shouldSample(at date: Date) -> Bool {
    guard let lastSampleDate else {
      return true
    }

    return date.timeIntervalSince(lastSampleDate) >= sampleIntervalSeconds
  }

  /// Reads one CPU sample and publishes the current widget state.
  private func sampleAndPublish(at date: Date) {
    lastSampleDate = date

    guard let usage = readCPUUsagePercent() else {
      publish()
      return
    }

    pushSample(usage)
    publish()
  }

  /// Publishes the current snapshot to the widget store.
  private func publish() {
    let snapshot = makeSnapshot()
    applyNodes(renderer.makeNodes(snapshot: snapshot))
  }

  /// Builds one render snapshot from config and current samples.
  private func makeSnapshot() -> Snapshot {
    return Snapshot(
      placement: config.placement,
      style: config.style,
      label: config.label,
      colorHex: config.colorHex ?? config.style.textColorHex,
      lineWidth: config.lineWidth,
      samples: samples
    )
  }

  /// Appends one clamped CPU sample and keeps the configured history size.
  private func pushSample(_ value: Double) {
    samples.append(min(max(value, 0), 100))

    while samples.count > historySize {
      samples.removeFirst()
    }

    while samples.count < historySize {
      samples.insert(0, at: 0)
    }
  }

  /// Returns the configured sample history size.
  private var historySize: Int {
    return max(2, config.historySize)
  }

  /// Returns the configured CPU sample interval in seconds.
  private var sampleIntervalSeconds: TimeInterval {
    return max(1, config.sampleIntervalSeconds)
  }

  /// Reads cumulative CPU tick counters from Mach.
  private func readCPUInfo() -> host_cpu_load_info_data_t? {
    let host = mach_host_self()
    defer {
      mach_port_deallocate(mach_task_self_, host)
    }

    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
    )

    let status = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
        host_statistics(
          host,
          HOST_CPU_LOAD_INFO,
          rebound,
          &count
        )
      }
    }

    return status == KERN_SUCCESS ? info : nil
  }

  /// Calculates whole-system CPU usage from the delta between two Mach samples.
  private func readCPUUsagePercent() -> Double? {
    guard let current = readCPUInfo() else { return nil }

    defer {
      previousCPUInfo = current
    }

    guard let previous = previousCPUInfo else {
      return nil
    }

    guard
      let user = tickDelta(current.cpu_ticks.0, previous.cpu_ticks.0),
      let system = tickDelta(current.cpu_ticks.1, previous.cpu_ticks.1),
      let idle = tickDelta(current.cpu_ticks.2, previous.cpu_ticks.2),
      let nice = tickDelta(current.cpu_ticks.3, previous.cpu_ticks.3)
    else {
      return nil
    }

    let active = user + system + nice
    let total = active + idle

    guard total > 0 else { return 0 }

    let percent = (Double(active) / Double(total)) * 100.0
    return min(max(percent, 0), 100)
  }

  /// Returns a safe positive tick delta, or nil if counters moved backwards.
  private func tickDelta(_ current: natural_t, _ previous: natural_t) -> UInt64? {
    let current = UInt64(current)
    let previous = UInt64(previous)

    guard current >= previous else {
      return nil
    }

    return current - previous
  }
}
