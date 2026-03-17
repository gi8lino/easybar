import Foundation
import Darwin.Mach

/// Native CPU sparkline widget.
///
/// CPU usage is sampled in Swift, so no shelling out is needed every second.
final class CPUSparklineNativeWidget: NativeWidget {

    let rootID = "builtin_cpu"

    private var timer: Timer?
    private var samples: [Double] = []
    private var previousCPUInfo: host_cpu_load_info_data_t?

    func start() {
        let historySize = max(2, Config.shared.builtinCPU.historySize)

        // Start with a fixed-size history so the sparkline shape is stable.
        samples = Array(repeating: 0, count: historySize)

        // Prime the CPU counters once.
        previousCPUInfo = readCPUInfo()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.sampleAndPublish()
        }

        publish()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        samples.removeAll()
        previousCPUInfo = nil

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    /// Reads one CPU sample and publishes the updated sparkline.
    private func sampleAndPublish() {
        let usage = readCPUUsagePercent() ?? 0
        pushSample(usage)
        publish()
    }

    /// Publishes the current native CPU widget node.
    private func publish() {
        let config = Config.shared.builtinCPU
        let style = config.style

        let node = WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: .sparkline,
            parent: nil,
            position: style.position,
            order: style.order,
            icon: style.icon,
            text: config.label,
            color: config.colorHex ?? style.textColorHex,
            visible: true,
            role: nil,
            imagePath: nil,
            imageSize: nil,
            imageCornerRadius: nil,
            fontSize: nil,
            value: nil,
            min: nil,
            max: nil,
            step: nil,
            values: samples,
            lineWidth: config.lineWidth,
            paddingX: style.paddingX,
            paddingY: style.paddingY,
            spacing: style.spacing,
            backgroundColor: style.backgroundColorHex,
            borderColor: style.borderColorHex,
            borderWidth: style.borderWidth,
            cornerRadius: style.cornerRadius,
            opacity: style.opacity
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }

    /// Appends one sample while keeping the configured history length.
    private func pushSample(_ value: Double) {
        let historySize = max(2, Config.shared.builtinCPU.historySize)

        samples.append(min(max(value, 0), 100))

        while samples.count > historySize {
            samples.removeFirst()
        }

        while samples.count < historySize {
            samples.insert(0, at: 0)
        }
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

    /// Computes CPU usage percentage from counter deltas.
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
