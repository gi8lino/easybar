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
