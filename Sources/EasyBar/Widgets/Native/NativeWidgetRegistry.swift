import Foundation

final class NativeWidgetRegistry {

    static let shared = NativeWidgetRegistry()

    private var widgets: [NativeWidget] = []

    private init() {}

    func start() {
        registerAll()
    }

    func reload() {
        registerAll()
    }

    func stop() {
        stopAll()
    }

    private func registerAll() {
        stopAll()

        var next: [NativeWidget] = []

        if Config.shared.builtinBattery.style.enabled {
            next.append(BatteryNativeWidget())
        }

        if Config.shared.builtinFrontApp.style.enabled {
            next.append(FrontAppNativeWidget())
        }

        if Config.shared.builtinVolume.style.enabled {
            next.append(VolumeSliderNativeWidget())
        }

        if Config.shared.builtinDate.style.enabled {
            next.append(DateNativeWidget())
        }

        if Config.shared.builtinTime.style.enabled {
            next.append(TimeNativeWidget())
        }

        if Config.shared.builtinCalendar.style.enabled {
            next.append(CalendarNativeWidget())
        }

        widgets = next

        for widget in widgets {
            widget.start()
        }
    }

    private func stopAll() {
        for widget in widgets {
            widget.stop()
        }

        widgets.removeAll()
    }
}
