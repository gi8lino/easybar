import EasyBarCalendarPresentation
import Foundation

extension CalendarEventComposer {
  /// Static display and timing metadata for one composer preset option.
  struct PresetMetadata {
    let seconds: TimeInterval?
    let fallbackTitle: String
  }

  /// Alert presets supported by the composer.
  public enum AlertOption: String, CaseIterable, Identifiable {
    case none
    case atTime = "at_time"
    case fiveMinutes = "5_minutes"
    case tenMinutes = "10_minutes"
    case fifteenMinutes = "15_minutes"
    case thirtyMinutes = "30_minutes"
    case oneHour = "1_hour"
    case oneDay = "1_day"
    case custom

    public var id: String { rawValue }

    var leadTimeSeconds: TimeInterval? {
      metadata.seconds
    }

    private var fallbackTitle: String {
      metadata.fallbackTitle
    }

    private var metadata: PresetMetadata {
      switch self {
      case .none:
        return PresetMetadata(seconds: nil, fallbackTitle: "None")
      case .atTime:
        return PresetMetadata(seconds: 0, fallbackTitle: "At time of event")
      case .fiveMinutes:
        return PresetMetadata(seconds: 5 * 60, fallbackTitle: "5 minutes before")
      case .tenMinutes:
        return PresetMetadata(seconds: 10 * 60, fallbackTitle: "10 minutes before")
      case .fifteenMinutes:
        return PresetMetadata(seconds: 15 * 60, fallbackTitle: "15 minutes before")
      case .thirtyMinutes:
        return PresetMetadata(seconds: 30 * 60, fallbackTitle: "30 minutes before")
      case .oneHour:
        return PresetMetadata(seconds: 60 * 60, fallbackTitle: "1 hour before")
      case .oneDay:
        return PresetMetadata(seconds: 24 * 60 * 60, fallbackTitle: "1 day before")
      case .custom:
        return PresetMetadata(seconds: nil, fallbackTitle: "Custom")
      }
    }

    static func from(configValue: String) -> AlertOption {
      AlertOption(rawValue: configValue) ?? .oneHour
    }

    func title(config: CalendarComposerConfig) -> String {
      configuredPresetTitle(labels: config.alertLabels)
    }

    private func configuredPresetTitle(labels: [String: String]) -> String {
      guard self != .custom else { return fallbackTitle }
      return labels[rawValue] ?? fallbackTitle
    }
  }

  /// Travel-time presets supported by the composer.
  public enum TravelTimeOption: String, CaseIterable, Identifiable {
    case none
    case fiveMinutes = "5_minutes"
    case tenMinutes = "10_minutes"
    case fifteenMinutes = "15_minutes"
    case twentyMinutes = "20_minutes"
    case thirtyMinutes = "30_minutes"
    case fortyFiveMinutes = "45_minutes"
    case oneHour = "1_hour"
    case ninetyMinutes = "90_minutes"
    case twoHours = "2_hours"
    case custom

    public var id: String { rawValue }

    var seconds: TimeInterval? {
      metadata.seconds
    }

    private var fallbackTitle: String {
      metadata.fallbackTitle
    }

    private var metadata: PresetMetadata {
      switch self {
      case .none:
        return PresetMetadata(seconds: nil, fallbackTitle: "None")
      case .fiveMinutes:
        return PresetMetadata(seconds: 5 * 60, fallbackTitle: "5 minutes")
      case .tenMinutes:
        return PresetMetadata(seconds: 10 * 60, fallbackTitle: "10 minutes")
      case .fifteenMinutes:
        return PresetMetadata(seconds: 15 * 60, fallbackTitle: "15 minutes")
      case .twentyMinutes:
        return PresetMetadata(seconds: 20 * 60, fallbackTitle: "20 minutes")
      case .thirtyMinutes:
        return PresetMetadata(seconds: 30 * 60, fallbackTitle: "30 minutes")
      case .fortyFiveMinutes:
        return PresetMetadata(seconds: 45 * 60, fallbackTitle: "45 minutes")
      case .oneHour:
        return PresetMetadata(seconds: 60 * 60, fallbackTitle: "1 hour")
      case .ninetyMinutes:
        return PresetMetadata(seconds: 90 * 60, fallbackTitle: "1.5 hours")
      case .twoHours:
        return PresetMetadata(seconds: 2 * 60 * 60, fallbackTitle: "2 hours")
      case .custom:
        return PresetMetadata(seconds: nil, fallbackTitle: "Custom")
      }
    }

    static func from(configValue: String) -> TravelTimeOption {
      TravelTimeOption(rawValue: configValue) ?? .none
    }

    func title(config: CalendarComposerConfig) -> String {
      configuredPresetTitle(labels: config.travelTimeLabels)
    }

    private func configuredPresetTitle(labels: [String: String]) -> String {
      guard self != .custom else { return fallbackTitle }
      return labels[rawValue] ?? fallbackTitle
    }
  }
}
