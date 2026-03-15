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
        if Config.shared.builtinBatteryEnabled {
            batteryWidget.start()
        }

        if Config.shared.builtinVolumeEnabled {
            volumeWidget.start()
        }

        if Config.shared.builtinDateEnabled {
            dateWidget.start()
        }

        if Config.shared.builtinTimeEnabled {
            timeWidget.start()
        }

        if Config.shared.builtinCalendarEnabled {
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
