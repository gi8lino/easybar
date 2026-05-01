import EasyBarShared
import Foundation
import SwiftUI

/// Complete in-memory config snapshot used for rollback.
struct ConfigSnapshot {
  /// App-level config snapshot.
  struct App {
    let widgetsPath: String
    let luaPath: String
    let environment: [String: String]
    let watchConfigFile: Bool
    let lockDirectory: String
    let widgetEditorStubPath: String
    let develop: Bool
  }

  /// Logging config snapshot.
  struct Logging {
    let enabled: Bool
    let level: ProcessLogLevel
    let directory: String
  }

  /// Calendar agent config snapshot.
  struct CalendarAgent {
    let enabled: Bool
    let socketPath: String
  }

  /// Network agent config snapshot.
  struct NetworkAgent {
    let enabled: Bool
    let socketPath: String
    let refreshIntervalSeconds: Double
    let allowUnauthorizedNonSensitiveFields: Bool
  }

  /// Built-in widget config snapshot.
  struct Builtins {
    let cpu: Config.CPUBuiltinConfig
    let battery: Config.BatteryBuiltinConfig
    let groups: [Config.BuiltinGroupConfig]
    let spaces: Config.SpacesBuiltinConfig
    let frontApp: Config.FrontAppBuiltinConfig
    let aerospaceMode: Config.AeroSpaceModeBuiltinConfig
    let volume: Config.VolumeBuiltinConfig
    let wifi: Config.WiFiBuiltinConfig
    let calendar: Config.CalendarBuiltinConfig
    let time: Config.TimeBuiltinConfig
    let date: Config.DateBuiltinConfig
  }

  /// App-level config values.
  let app: App
  /// Logging config values.
  let logging: Logging
  /// Calendar agent config values.
  let calendarAgent: CalendarAgent
  /// Network agent config values.
  let networkAgent: NetworkAgent
  /// Bar config values.
  let bar: Config.BarSection
  /// Built-in widget config values.
  let builtins: Builtins
}
