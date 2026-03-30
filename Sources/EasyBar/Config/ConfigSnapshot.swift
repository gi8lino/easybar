import Foundation
import SwiftUI

struct ConfigSnapshot {
  struct App {
    let widgetsPath: String
    let luaPath: String
    let watchConfigFile: Bool
    let loggingEnabled: Bool
    let loggingDebugEnabled: Bool
    let loggingDirectory: String
    let calendarAgentEnabled: Bool
    let calendarAgentSocketPath: String
    let networkAgentEnabled: Bool
    let networkAgentSocketPath: String
    let networkAgentRefreshIntervalSeconds: Double
    let networkAgentAllowUnauthorizedNonSensitiveFields: Bool
  }

  struct Bar {
    let height: CGFloat
    let paddingX: CGFloat
    let extendBehindNotch: Bool
    let backgroundHex: String
    let borderHex: String
  }

  struct Builtins {
    let cpu: Config.CPUBuiltinConfig
    let battery: Config.BatteryBuiltinConfig
    let groups: [Config.BuiltinGroupConfig]
    let spaces: Config.SpacesBuiltinConfig
    let frontApp: Config.FrontAppBuiltinConfig
    let volume: Config.VolumeBuiltinConfig
    let wifi: Config.WiFiBuiltinConfig
    let calendar: Config.CalendarBuiltinConfig
    let time: Config.TimeBuiltinConfig
    let date: Config.DateBuiltinConfig
  }

  let app: App
  let bar: Bar
  let builtins: Builtins
}
