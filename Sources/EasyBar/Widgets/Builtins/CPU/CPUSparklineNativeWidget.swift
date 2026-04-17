import Darwin.Mach
import Foundation

@MainActor
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

  private lazy var renderer = CPURenderer(rootID: rootID)

  struct Snapshot {
    let placement: Config.BuiltinWidgetPlacement
    let style: Config.BuiltinWidgetStyle
    let label: String
    let colorHex: String?
    let lineWidth: Double
    let samples: [Double]
  }

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
      case .routineTick:
        break
      default:
        break
      }
    }

    publish()
  }

  func stop() {
    eventObserver.stop()
    samples.removeAll()
    previousCPUInfo = nil

    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  private func sampleAndPublish() {
    let usage = readCPUUsagePercent() ?? 0
    pushSample(usage)
    publish()
  }

  private func publish() {
    let snapshot = makeSnapshot()
    WidgetStore.shared.apply(root: rootID, nodes: renderer.makeNodes(snapshot: snapshot))
  }

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

  private func pushSample(_ value: Double) {
    samples.append(min(max(value, 0), 100))

    while samples.count > historySize {
      samples.removeFirst()
    }

    while samples.count < historySize {
      samples.insert(0, at: 0)
    }
  }

  private var historySize: Int {
    max(2, Config.shared.builtinCPU.historySize)
  }

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

    return status == KERN_SUCCESS ? info : nil
  }

  private func readCPUUsagePercent() -> Double? {
    guard let current = readCPUInfo() else { return nil }
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

    return total > 0 ? (active / total) * 100.0 : 0
  }
}
