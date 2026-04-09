import EasyBarShared
import Foundation
import SwiftUI

struct ConfigSnapshot {
  struct App {
    let widgetsPath: String
    let luaPath: String
    let watchConfigFile: Bool
    let lockDirectory: String
  }

  struct Logging {
    let enabled: Bool
    let level: ProcessLogLevel
    let directory: String
  }

  struct CalendarAgent {
    let enabled: Bool
    let socketPath: String
  }

  struct NetworkAgent {
    let enabled: Bool
    let socketPath: String
    let refreshIntervalSeconds: Double
    let allowUnauthorizedNonSensitiveFields: Bool
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
    let aerospaceMode: Config.AeroSpaceModeBuiltinConfig
    let volume: Config.VolumeBuiltinConfig
    let wifi: Config.WiFiBuiltinConfig
    let calendar: Config.CalendarBuiltinConfig
    let time: Config.TimeBuiltinConfig
    let date: Config.DateBuiltinConfig
  }

  let app: App
  let logging: Logging
  let calendarAgent: CalendarAgent
  let networkAgent: NetworkAgent
  let bar: Bar
  let builtins: Builtins
}
