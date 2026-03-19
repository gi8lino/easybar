import Foundation

final class NativeWidgetRegistry {

    static let shared = NativeWidgetRegistry()

    private var widgets: [NativeWidget] = []

    /// Starts all enabled native widgets.
    func start() {
        registerAll()
    }

    /// Rebuilds the native widget list from config.
    func reload() {
        registerAll()
    }

    /// Stops all native widgets.
    func stop() {
        stopAll()
    }

    /// Registers all enabled native widgets.
    private func registerAll() {
        stopAll()

        Logger.info("registering native widgets")
        Logger.info("native widget config spaces=\(Config.shared.builtinSpaces.enabled) battery=\(Config.shared.builtinBattery.enabled) front_app=\(Config.shared.builtinFrontApp.enabled) volume=\(Config.shared.builtinVolume.enabled) date=\(Config.shared.builtinDate.enabled) time=\(Config.shared.builtinTime.enabled) calendar=\(Config.shared.builtinCalendar.enabled) cpu=\(Config.shared.builtinCPU.enabled)")

        var next: [NativeWidget] = []

        if Config.shared.builtinSpaces.enabled {
            next.append(SpacesNativeWidget())
        }

        if Config.shared.builtinBattery.enabled {
            next.append(BatteryNativeWidget())
        }

        if Config.shared.builtinFrontApp.enabled {
            next.append(FrontAppNativeWidget())
        }

        if Config.shared.builtinVolume.enabled {
            next.append(VolumeSliderNativeWidget())
        }

        if Config.shared.builtinDate.enabled {
            next.append(DateNativeWidget())
        }

        if Config.shared.builtinTime.enabled {
            next.append(TimeNativeWidget())
        }

        if Config.shared.builtinCalendar.enabled {
            next.append(CalendarNativeWidget())
        }

        if Config.shared.builtinCPU.enabled {
            next.append(CPUSparklineNativeWidget())
        }

        widgets = next

        Logger.info("native widgets registered count=\(widgets.count) ids=\(widgets.map(\.rootID).joined(separator: ","))")

        for widget in widgets {
            widget.start()
        }
    }

    /// Stops and clears all widgets.
    private func stopAll() {
        for widget in widgets {
            widget.stop()
        }

        widgets.removeAll()
    }
}
