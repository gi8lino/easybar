import EasyBarShared
import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config: ObservableObject {
  static let shared = Config()

  enum LoadFailureContext {
    case initialLoad
    case reloadKeptPreviousConfig
  }

  struct LoadFailureState {
    let error: any Error
    let context: LoadFailureContext
  }

  // MARK: - Sections

  struct AppSection {
    var widgetsPath: String
    var luaPath: String
    var environment: [String: String]
    var watchConfigFile: Bool
    var lockDirectory: String
  }

  struct LoggingSection {
    var enabled: Bool
    var level: ProcessLogLevel
    var directory: String
  }

  struct CalendarAgentSection {
    var enabled: Bool
    var socketPath: String
  }

  struct NetworkAgentSection {
    var enabled: Bool
    var socketPath: String
    var refreshIntervalSeconds: Double
    var allowUnauthorizedNonSensitiveFields: Bool
  }

  struct BarSection {
    var height: CGFloat
    var paddingX: CGFloat
    var extendBehindNotch: Bool
    var backgroundHex: String
    var borderHex: String

    static let `default` = BarSection(
      height: 32,
      paddingX: 10,
      extendBehindNotch: true,
      backgroundHex: "#111111",
      borderHex: "#222222"
    )
  }

  // MARK: - Stored config sections

  var appSection: AppSection
  var loggingSection: LoggingSection
  var calendarAgentSection: CalendarAgentSection
  var networkAgentSection: NetworkAgentSection
  var barSection: BarSection

  // MARK: - App compatibility accessors

  var widgetsPath: String {
    get { appSection.widgetsPath }
    set { appSection.widgetsPath = newValue }
  }

  var luaPath: String {
    get { appSection.luaPath }
    set { appSection.luaPath = newValue }
  }

  var watchConfigFile: Bool {
    get { appSection.watchConfigFile }
    set { appSection.watchConfigFile = newValue }
  }

  var lockDirectory: String {
    get { appSection.lockDirectory }
    set { appSection.lockDirectory = newValue }
  }

  var loggingEnabled: Bool {
    get { loggingSection.enabled }
    set { loggingSection.enabled = newValue }
  }

  var loggingLevel: ProcessLogLevel {
    get { loggingSection.level }
    set { loggingSection.level = newValue }
  }

  var loggingDebugEnabled: Bool {
    get { loggingSection.level.allows(.debug) }
    set { loggingSection.level = newValue ? .debug : .info }
  }

  var loggingTraceEnabled: Bool {
    get { loggingSection.level.allows(.trace) }
    set { loggingSection.level = newValue ? .trace : .info }
  }

  var loggingDirectory: String {
    get { loggingSection.directory }
    set { loggingSection.directory = newValue }
  }

  var calendarAgentEnabled: Bool {
    get { calendarAgentSection.enabled }
    set { calendarAgentSection.enabled = newValue }
  }

  var calendarAgentSocketPath: String {
    get { calendarAgentSection.socketPath }
    set { calendarAgentSection.socketPath = newValue }
  }

  var networkAgentEnabled: Bool {
    get { networkAgentSection.enabled }
    set { networkAgentSection.enabled = newValue }
  }

  var networkAgentSocketPath: String {
    get { networkAgentSection.socketPath }
    set { networkAgentSection.socketPath = newValue }
  }

  var networkAgentRefreshIntervalSeconds: Double {
    get { networkAgentSection.refreshIntervalSeconds }
    set { networkAgentSection.refreshIntervalSeconds = newValue }
  }

  var networkAgentAllowUnauthorizedNonSensitiveFields: Bool {
    get { networkAgentSection.allowUnauthorizedNonSensitiveFields }
    set { networkAgentSection.allowUnauthorizedNonSensitiveFields = newValue }
  }

  // MARK: - Bar compatibility accessors

  var barHeight: CGFloat {
    get { barSection.height }
    set { barSection.height = newValue }
  }

  var barPaddingX: CGFloat {
    get { barSection.paddingX }
    set { barSection.paddingX = newValue }
  }

  var barExtendBehindNotch: Bool {
    get { barSection.extendBehindNotch }
    set { barSection.extendBehindNotch = newValue }
  }

  var barBackgroundHex: String {
    get { barSection.backgroundHex }
    set { barSection.backgroundHex = newValue }
  }

  var barBorderHex: String {
    get { barSection.borderHex }
    set { barSection.borderHex = newValue }
  }

  // MARK: - Builtins

  var builtinCPU: CPUBuiltinConfig = .default
  var builtinBattery: BatteryBuiltinConfig = .default
  var builtinGroups: [BuiltinGroupConfig] = []
  var builtinSpaces: SpacesBuiltinConfig = .default
  var builtinFrontApp: FrontAppBuiltinConfig = .default
  var builtinAeroSpaceMode: AeroSpaceModeBuiltinConfig = .default
  var builtinVolume: VolumeBuiltinConfig = .default
  var builtinWiFi: WiFiBuiltinConfig = .default
  var builtinCalendar: CalendarBuiltinConfig = .default
  var builtinTime: TimeBuiltinConfig = .default
  var builtinDate: DateBuiltinConfig = .default

  private(set) var loadFailureState: LoadFailureState?

  private init() {
    appSection = .init(
      widgetsPath: "",
      luaPath: SharedPathDefaults.defaultLuaPath,
      environment: Self.defaultAppEnvironment(),
      watchConfigFile: true,
      lockDirectory: ""
    )
    loggingSection = .init(
      enabled: false,
      level: .info,
      directory: ""
    )
    calendarAgentSection = .init(
      enabled: true,
      socketPath: ""
    )
    networkAgentSection = .init(
      enabled: true,
      socketPath: "",
      refreshIntervalSeconds: 0,
      allowUnauthorizedNonSensitiveFields: false
    )
    barSection = .default

    resetDerivedDefaults()

    do {
      try load()
      loadFailureState = nil
    } catch {
      let message = "invalid config at \(configPath): \(error)"
      easybarLog.error(message)
      fputs("easybar: \(message)\n", stderr)
      loadFailureState = LoadFailureState(error: error, context: .initialLoad)
    }
  }

  /// Reloads config from disk and returns one validation error when reload fails.
  @discardableResult
  func reload() -> (any Error)? {
    easybarLog.info("reloading configuration path=\(configPath)")

    let snapshot = snapshot()
    resetToDefaults()

    do {
      try load()
      loadFailureState = nil
      objectWillChange.send()

      easybarLog.info("reload applied")
      return nil
    } catch {
      apply(snapshot)
      loadFailureState = LoadFailureState(error: error, context: .reloadKeptPreviousConfig)

      easybarLog.warn("reload rejected: \(error)")
      return error
    }
  }

  /// Absolute path to the active config file.
  var configPath: String {
    if let override = environmentConfigPathOverride() {
      return override
    }

    return SharedPathDefaults.defaultConfigPath()
  }

  /// Restores all defaults before parsing again.
  func resetToDefaults() {
    resetStaticDefaults()
    resetDerivedDefaults()
  }

  /// Restores bar defaults.
  func resetBarDefaults() {
    barSection = .default
  }

  /// Restores built-in widget defaults.
  func resetBuiltinDefaults() {
    builtinCPU = .default
    builtinBattery = .default
    builtinGroups = []
    builtinSpaces = .default
    builtinFrontApp = .default
    builtinAeroSpaceMode = .default
    builtinVolume = .default
    builtinWiFi = .default
    builtinCalendar = .default
    builtinTime = .default
    builtinDate = .default
  }
}
