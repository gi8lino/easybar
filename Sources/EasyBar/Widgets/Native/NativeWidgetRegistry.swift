import Foundation

final class NativeWidgetRegistry {

    static let shared = NativeWidgetRegistry()

    private let batteryWidget = BatteryNativeWidget()
    private let volumeWidget = VolumeSliderNativeWidget()
    private let dateWidget = DateNativeWidget()
    private let timeWidget = TimeNativeWidget()
    private let calendarWidget = CalendarNativeWidget()

    private init() {}

    func start() {
        if Config.shared.builtinBattery.style.enabled {
            batteryWidget.start()
        }

        if Config.shared.builtinVolume.style.enabled {
            volumeWidget.start()
        }

        if Config.shared.builtinDate.style.enabled {
            dateWidget.start()
        }

        if Config.shared.builtinTime.style.enabled {
            timeWidget.start()
        }

        if Config.shared.builtinCalendar.style.enabled {
            calendarWidget.start()
        }
    }

    func stop() {
        batteryWidget.stop()
        volumeWidget.stop()
        dateWidget.stop()
        timeWidget.stop()
        calendarWidget.stop()
    }

    func reload() {
        stop()
        start()
    }
}
