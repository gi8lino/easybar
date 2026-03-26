import Foundation
import SwiftUI

struct ConfigSnapshot {
    let widgetsPath: String
    let luaPath: String
    let watchConfigFile: Bool
    let loggingEnabled: Bool
    let loggingDebugEnabled: Bool
    let loggingPath: String
    let calendarAgentEnabled: Bool
    let calendarAgentSocketPath: String
    let networkAgentEnabled: Bool
    let networkAgentSocketPath: String
    let networkAgentRefreshIntervalSeconds: Double

    let barHeight: CGFloat
    let barPaddingX: CGFloat
    let barExtendBehindNotch: Bool

    let barBackgroundHex: String
    let barBorderHex: String

    let builtinCPU: Config.CPUBuiltinConfig
    let builtinBattery: Config.BatteryBuiltinConfig
    let builtinGroups: [Config.BuiltinGroupConfig]
    let builtinSpaces: Config.SpacesBuiltinConfig
    let builtinFrontApp: Config.FrontAppBuiltinConfig
    let builtinVolume: Config.VolumeBuiltinConfig
    let builtinWiFi: Config.WiFiBuiltinConfig
    let builtinCalendar: Config.CalendarBuiltinConfig
    let builtinTime: Config.TimeBuiltinConfig
    let builtinDate: Config.DateBuiltinConfig
}
