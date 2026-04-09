import Darwin.Mach
import Foundation

/// Native CPU sparkline widget.
final class CPUSparklineNativeWidget: NativeWidget {

  let rootID = "builtin_cpu"

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.secondTick.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  private let eventObserver = EasyBarEventObserver()
  private var samples: [Double] = []
  private var previousCPUInfo: host_cpu_load_info_data_t?

  private struct Snapshot {
    let placement: Config.BuiltinWidgetPlacement
    let style: Config.BuiltinWidgetStyle
    let label: String
    let colorHex: String?
    let lineWidth: Double
    let samples: [Double]
  }

  /// Starts CPU sampling.
  func start() {
    samples = Array(repeating: 0, count: historySize)
    previousCPUInfo = readCPUInfo()

    NativeWidgetEventDriver.start(observer: eventObserver) { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }

      switch event {
      case .secondTick:
        self.sampleAndPublish()
      case .systemWoke:
        self.previousCPUInfo = self.readCPUInfo()
        self.publish()
      default:
        break
      }
    }

    publish()
  }

  /// Stops CPU sampling.
  func stop() {
    eventObserver.stop()
    samples.removeAll()
    previousCPUInfo = nil

    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  /// Reads one CPU sample and republishes.
  private func sampleAndPublish() {
    let usage = readCPUUsagePercent() ?? 0
    pushSample(usage)
    publish()
  }

  /// Publishes the current sparkline node.
  private func publish() {
    let snapshot = makeSnapshot()
    WidgetStore.shared.apply(root: rootID, nodes: [makeNode(snapshot: snapshot)])
  }

  /// Returns the current render snapshot.
  private func makeSnapshot() -> Snapshot {
    let config = Config.shared.builtinCPU
    return Snapshot(
      placement: config.placement,
      style: config.style,
      label: config.label,
      colorHex: config.colorHex ?? config.style.textColorHex,
      lineWidth: config.lineWidth,
      samples: samples
    )
  }

  /// Appends one sample and keeps the configured history size.
  private func pushSample(_ value: Double) {
    samples.append(min(max(value, 0), 100))

    while samples.count > historySize {
      samples.removeFirst()
    }

    while samples.count < historySize {
      samples.insert(0, at: 0)
    }
  }

  /// Returns the configured history size with the minimum enforced.
  private var historySize: Int {
    max(2, Config.shared.builtinCPU.historySize)
  }

  /// Builds the sparkline node from the current samples.
  private func makeNode(snapshot: Snapshot) -> WidgetNodeState {
    WidgetNodeState(
      id: rootID,
      root: rootID,
      kind: .sparkline,
      parent: snapshot.placement.groupID,
      position: snapshot.placement.position,
      order: snapshot.placement.order,
      icon: snapshot.style.icon,
      text: snapshot.label,
      color: snapshot.colorHex,
      iconColor: nil,
      labelColor: nil,
      visible: true,
      role: nil,
      receivesMouseHover: nil,
      receivesMouseClick: nil,
      receivesMouseScroll: nil,
      imagePath: nil,
      imageSize: nil,
      imageCornerRadius: nil,
      fontSize: nil,
      iconFontSize: nil,
      labelFontSize: nil,
      value: nil,
      min: nil,
      max: nil,
      step: nil,
      values: snapshot.samples,
      lineWidth: snapshot.lineWidth,
      paddingX: snapshot.style.paddingX,
      paddingY: snapshot.style.paddingY,
      paddingLeft: nil,
      paddingRight: nil,
      paddingTop: nil,
      paddingBottom: nil,
      marginX: snapshot.style.marginX,
      marginY: snapshot.style.marginY,
      marginLeft: nil,
      marginRight: nil,
      marginTop: nil,
      marginBottom: nil,
      spacing: snapshot.style.spacing,
      backgroundColor: snapshot.style.backgroundColorHex,
      borderColor: snapshot.style.borderColorHex,
      borderWidth: snapshot.style.borderWidth,
      cornerRadius: snapshot.style.cornerRadius,
      opacity: snapshot.style.opacity,
      width: nil,
      height: nil,
      yOffset: nil
    )
  }

  /// Reads current host CPU counters.
  private func readCPUInfo() -> host_cpu_load_info_data_t? {
    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
    )

    let status = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
        host_statistics(
          mach_host_self(),
          HOST_CPU_LOAD_INFO,
          rebound,
          &count
        )
      }
    }

    guard status == KERN_SUCCESS else {
      return nil
    }

    return info
  }

  /// Computes CPU usage from counter deltas.
  private func readCPUUsagePercent() -> Double? {
    guard let current = readCPUInfo() else {
      return nil
    }

    guard let previous = previousCPUInfo else {
      previousCPUInfo = current
      return nil
    }

    previousCPUInfo = current

    let user = Double(current.cpu_ticks.0 - previous.cpu_ticks.0)
    let system = Double(current.cpu_ticks.1 - previous.cpu_ticks.1)
    let idle = Double(current.cpu_ticks.2 - previous.cpu_ticks.2)
    let nice = Double(current.cpu_ticks.3 - previous.cpu_ticks.3)

    let active = user + system + nice
    let total = active + idle

    guard total > 0 else {
      return 0
    }

    return (active / total) * 100.0
  }
}
