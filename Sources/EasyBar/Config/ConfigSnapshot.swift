import Foundation
import SwiftUI

struct ConfigSnapshot {
    let barHeight: CGFloat
    let barPadding: CGFloat

    let barBackgroundHex: String
    let barBorderHex: String
    let textColorHex: String
    let focusedAppBorderHex: String

    let luaPath: String

    let logToFile: Bool
    let logFilePath: String

    let builtinCPU: Config.CPUBuiltinConfig
    let builtinBattery: Config.BatteryBuiltinConfig
    let builtinSpaces: Config.SpacesBuiltinConfig
    let builtinFrontApp: Config.FrontAppBuiltinConfig
    let builtinVolume: Config.VolumeBuiltinConfig
    let builtinDate: Config.DateBuiltinConfig
    let builtinTime: Config.TimeBuiltinConfig
    let builtinCalendar: Config.CalendarBuiltinConfig

    let widgetsPath: String
}
