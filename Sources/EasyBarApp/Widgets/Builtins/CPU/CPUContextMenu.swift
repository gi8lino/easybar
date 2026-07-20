import Foundation

/// Actions exposed by the native CPU widget context menu.
enum CPUContextMenuAction: Equatable {
  case setHistorySize(Int)
  case setSampleInterval(Int)
  case resetHistory
  case openActivityMonitor

  /// Decodes one stable context-menu action identifier.
  init?(id: String) {
    if let value = Self.allowedHistorySizes.first(where: { id == "cpu.history.\($0)" }) {
      self = .setHistorySize(value)
      return
    }

    if let value = Self.allowedSampleIntervals.first(where: { id == "cpu.interval.\($0)" }) {
      self = .setSampleInterval(value)
      return
    }

    switch id {
    case "cpu.reset_history": self = .resetHistory
    case "cpu.open_activity_monitor": self = .openActivityMonitor
    default: return nil
    }
  }

  static let allowedHistorySizes = [10, 30, 60]
  static let allowedSampleIntervals = [1, 2, 5]
}

/// Builds the native CPU context menu from the effective configuration.
enum CPUContextMenu {
  static func make(config: Config.CPUBuiltinConfig) -> [WidgetContextMenuItem] {
    let historyItems = CPUContextMenuAction.allowedHistorySizes.map { size in
      WidgetContextMenuItem(
        id: "cpu.history.\(size)",
        title: "\(size) Samples",
        checked: config.historySize == size
      )
    }

    let intervalItems = CPUContextMenuAction.allowedSampleIntervals.map { seconds in
      WidgetContextMenuItem(
        id: "cpu.interval.\(seconds)",
        title: seconds == 1 ? "1 Second" : "\(seconds) Seconds",
        checked: config.sampleIntervalSeconds == Double(seconds)
      )
    }

    return [
      WidgetContextMenuItem(
        id: "cpu.open_activity_monitor",
        title: "Open Activity Monitor"
      ),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(title: "History", submenu: historyItems),
      WidgetContextMenuItem(title: "Refresh Interval", submenu: intervalItems),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(id: "cpu.reset_history", title: "Reset History"),
    ]
  }
}
