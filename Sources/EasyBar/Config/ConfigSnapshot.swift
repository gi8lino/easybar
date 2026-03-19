import Foundation
import SwiftUI

struct ConfigSnapshot {
    let widgetsPath: String
    let luaPath: String
    let watchConfigFile: Bool

    let barHeight: CGFloat
    let barPaddingX: CGFloat
    let barExtendBehindNotch: Bool

    let barBackgroundHex: String
    let barBorderHex: String

    let builtinCPU: Config.CPUBuiltinConfig
    let builtinBattery: Config.BatteryBuiltinConfig
    let builtinSpaces: Config.SpacesBuiltinConfig
    let builtinFrontApp: Config.FrontAppBuiltinConfig
    let builtinVolume: Config.VolumeBuiltinConfig
    let builtinCalendar: Config.CalendarBuiltinConfig
    let builtinTime: Config.TimeBuiltinConfig
    let builtinDate: Config.DateBuiltinConfig
}
