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
        logConfig()
        NativeGroupRegistry.shared.reload()
        widgets = makeEnabledWidgets()
        logRegisteredWidgets()
        startWidgets()
    }

    /// Stops and clears all widgets.
    private func stopAll() {
        for widget in widgets {
            widget.stop()
        }

        widgets.removeAll()
        NativeGroupRegistry.shared.clear()
    }

    /// Builds the enabled native widget list from the current config.
    private func makeEnabledWidgets() -> [NativeWidget] {
        var widgets: [NativeWidget] = []

        appendWidgetIfEnabled(Config.shared.builtinSpaces.enabled, widget: SpacesNativeWidget(), to: &widgets)
        appendWidgetIfEnabled(Config.shared.builtinBattery.enabled, widget: BatteryNativeWidget(), to: &widgets)
        appendWidgetIfEnabled(Config.shared.builtinFrontApp.enabled, widget: FrontAppNativeWidget(), to: &widgets)
        appendWidgetIfEnabled(Config.shared.builtinVolume.enabled, widget: VolumeSliderNativeWidget(), to: &widgets)
        appendWidgetIfEnabled(Config.shared.builtinWiFi.enabled, widget: WiFiNativeWidget(), to: &widgets)
        appendWidgetIfEnabled(Config.shared.builtinDate.enabled, widget: DateNativeWidget(), to: &widgets)
        appendWidgetIfEnabled(Config.shared.builtinTime.enabled, widget: TimeNativeWidget(), to: &widgets)
        appendWidgetIfEnabled(Config.shared.builtinCalendar.enabled, widget: CalendarNativeWidget(), to: &widgets)
        appendWidgetIfEnabled(Config.shared.builtinCPU.enabled, widget: CPUSparklineNativeWidget(), to: &widgets)

        return widgets
    }

    /// Appends one widget when its config flag is enabled.
    private func appendWidgetIfEnabled(
        _ enabled: Bool,
        widget: NativeWidget,
        to widgets: inout [NativeWidget]
    ) {
        guard enabled else { return }
        widgets.append(widget)
    }

    /// Logs the current built-in widget enablement snapshot.
    private func logConfig() {
        Logger.info("native widget config spaces=\(Config.shared.builtinSpaces.enabled) battery=\(Config.shared.builtinBattery.enabled) front_app=\(Config.shared.builtinFrontApp.enabled) volume=\(Config.shared.builtinVolume.enabled) wifi=\(Config.shared.builtinWiFi.enabled) date=\(Config.shared.builtinDate.enabled) time=\(Config.shared.builtinTime.enabled) calendar=\(Config.shared.builtinCalendar.enabled) cpu=\(Config.shared.builtinCPU.enabled)")
    }

    /// Logs the final registered widget ids.
    private func logRegisteredWidgets() {
        Logger.info("native widgets registered count=\(widgets.count) ids=\(widgets.map(\.rootID).joined(separator: ","))")
    }

    /// Starts all currently registered widgets.
    private func startWidgets() {
        for widget in widgets {
            widget.start()
        }
    }
}
