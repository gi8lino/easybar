import EasyBarShared
import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config: ObservableObject {
  /// Shared process-wide config instance.
  static let shared = Config()

  /// Context in which config loading failed.
  enum LoadFailureContext {
    /// Initial startup could not load config.
    case initialLoad
    /// Reload failed and the previous config stayed active.
    case reloadKeptPreviousConfig
  }

  /// Captures the latest config load failure.
  struct LoadFailureState {
    /// Underlying load or validation error.
    let error: any Error
    /// Load phase where the error occurred.
    let context: LoadFailureContext
  }

  // MARK: - Sections

  /// App-level config values.
  struct AppSection {
    struct LuaCommandLimits: Equatable {
      var timeoutSeconds: TimeInterval
      var maxOutputBytes: Int
      var maxAsyncJobs: Int
    }

    var widgetsPath: String
    var luaPath: String
    var luaSocketPath: String
    var environment: [String: String]
    var watchConfigFile: Bool
    var lockDirectory: String
    var widgetEditorStubPath: String
    var develop: Bool
    var luaCommandLimits: LuaCommandLimits
  }

  /// Logging config values.
  struct LoggingSection {
    var enabled: Bool
    var level: ProcessLogLevel
    var directory: String
  }

  /// Calendar agent config values.
  struct CalendarAgentSection {
    var enabled: Bool
    var socketPath: String
  }

  /// Network agent config values.
  struct NetworkAgentSection {
    var enabled: Bool
    var socketPath: String
    var refreshIntervalSeconds: Double
    var allowUnauthorizedNonSensitiveFields: Bool
  }

  /// Theme color tokens used as defaults and references.
  struct ThemeColors: Equatable {
    var background: String
    var surface: String
    var surfaceElevated: String
    var surfaceHover: String
    var text: String
    var textSecondary: String
    var textTertiary: String
    var muted: String
    var mutedSecondary: String
    var outsideMonth: String
    var accent: String
    var accentSecondary: String
    var accentSoft: String
    var success: String
    var successSecondary: String
    var warning: String
    var orange: String
    var error: String
    var danger: String
    var border: String
    var borderStrong: String
    var borderSubtle: String
    var selectionText: String
    var selectionBackground: String
    var transparent: String
    var overlayOutline: String
    var overlayText: String
    var todayButtonBorder: String
  }

  /// Theme config values.
  struct ThemeSection: Equatable {
    var name: String
    var themesDir: String
    var colors: ThemeColors

    /// Bootstrap fallback used before the bundled default theme is parsed.
    static let `default` = ThemeSection(
      name: "default",
      themesDir: "",
      colors: .init(
        background: "#111111",
        surface: "#1a1a1a",
        surfaceElevated: "#2b2b2b",
        surfaceHover: "#202020",
        text: "#ffffff",
        textSecondary: "#d0d0d0",
        textTertiary: "#c0c0c0",
        muted: "#6c7086",
        mutedSecondary: "#8a8a8a",
        outsideMonth: "#6e738d",
        accent: "#91d7e3",
        accentSecondary: "#89B4FA",
        accentSoft: "#8bd5ca",
        success: "#a6e3a1",
        successSecondary: "#a6da95",
        warning: "#f9e2af",
        orange: "#fab387",
        error: "#f38ba8",
        danger: "#FF0000",
        border: "#333333",
        borderStrong: "#444444",
        borderSubtle: "#00000000",
        selectionText: "#0B1020",
        selectionBackground: "#89B4FA",
        transparent: "#00000000",
        overlayOutline: "#000000F0",
        overlayText: "#FFFFFFFF",
        todayButtonBorder: "#3F2F6B"
      )
    )
  }

  /// Bar layout and color config values.
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
      backgroundHex: ThemeSection.default.colors.background,
      borderHex: ThemeSection.default.colors.transparent
    )
  }

  // MARK: - Stored config sections

  var appSection: AppSection
  var loggingSection: LoggingSection
  var calendarAgentSection: CalendarAgentSection
  var networkAgentSection: NetworkAgentSection
  var themeSection: ThemeSection
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

  var luaSocketPath: String {
    get { appSection.luaSocketPath }
    set { appSection.luaSocketPath = newValue }
  }

  var watchConfigFile: Bool {
    get { appSection.watchConfigFile }
    set { appSection.watchConfigFile = newValue }
  }

  var lockDirectory: String {
    get { appSection.lockDirectory }
    set { appSection.lockDirectory = newValue }
  }

  var widgetEditorStubPath: String {
    get { appSection.widgetEditorStubPath }
    set { appSection.widgetEditorStubPath = newValue }
  }

  var develop: Bool {
    get { appSection.develop }
    set { appSection.develop = newValue }
  }

  var luaCommandTimeoutSeconds: TimeInterval {
    get { appSection.luaCommandLimits.timeoutSeconds }
    set { appSection.luaCommandLimits.timeoutSeconds = newValue }
  }

  var luaCommandMaxOutputBytes: Int {
    get { appSection.luaCommandLimits.maxOutputBytes }
    set { appSection.luaCommandLimits.maxOutputBytes = newValue }
  }

  var luaCommandMaxAsyncJobs: Int {
    get { appSection.luaCommandLimits.maxAsyncJobs }
    set { appSection.luaCommandLimits.maxAsyncJobs = newValue }
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

  // MARK: - Theme accessors

  var themeName: String {
    get { themeSection.name }
    set { themeSection.name = newValue }
  }

  var themesDir: String {
    get { themeSection.themesDir }
    set { themeSection.themesDir = newValue }
  }

  var themeColors: ThemeColors {
    get { themeSection.colors }
    set { themeSection.colors = newValue }
  }

  var themeBackgroundHex: String { themeSection.colors.background }
  var themeSurfaceHex: String { themeSection.colors.surface }
  var themeSurfaceElevatedHex: String { themeSection.colors.surfaceElevated }
  var themeSurfaceHoverHex: String { themeSection.colors.surfaceHover }
  var themeTextColorHex: String { themeSection.colors.text }
  var themeTextSecondaryColorHex: String { themeSection.colors.textSecondary }
  var themeTextTertiaryColorHex: String { themeSection.colors.textTertiary }
  var themeMutedColorHex: String { themeSection.colors.muted }
  var themeMutedSecondaryColorHex: String { themeSection.colors.mutedSecondary }
  var themeOutsideMonthColorHex: String { themeSection.colors.outsideMonth }
  var themeAccentColorHex: String { themeSection.colors.accent }
  var themeAccentSecondaryColorHex: String { themeSection.colors.accentSecondary }
  var themeAccentSoftColorHex: String { themeSection.colors.accentSoft }
  var themeSuccessColorHex: String { themeSection.colors.success }
  var themeSuccessSecondaryColorHex: String { themeSection.colors.successSecondary }
  var themeWarningColorHex: String { themeSection.colors.warning }
  var themeOrangeColorHex: String { themeSection.colors.orange }
  var themeErrorColorHex: String { themeSection.colors.error }
  var themeDangerColorHex: String { themeSection.colors.danger }
  var themeBorderColorHex: String { themeSection.colors.border }
  var themeBorderStrongColorHex: String { themeSection.colors.borderStrong }
  var themeBorderSubtleColorHex: String { themeSection.colors.borderSubtle }
  var themeSelectionTextColorHex: String { themeSection.colors.selectionText }
  var themeSelectionBackgroundColorHex: String { themeSection.colors.selectionBackground }
  var themeTransparentColorHex: String { themeSection.colors.transparent }
  var themeOverlayOutlineColorHex: String { themeSection.colors.overlayOutline }
  var themeOverlayTextColorHex: String { themeSection.colors.overlayText }
  var themeTodayButtonBorderColorHex: String { themeSection.colors.todayButtonBorder }

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

  var barShowsBorder: Bool {
    return !barBorderHex.isFullyTransparentHexColor
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

  // MARK: - Transient config state

  /// Most recent config load failure, when any.
  private(set) var loadFailureState: LoadFailureState?
  /// Runtime directories required by parsed config.
  var registeredDirectories: [String: RequiredDirectory] = [:]

  private init() {
    appSection = .init(
      widgetsPath: "",
      luaPath: SharedPathDefaults.defaultLuaPath,
      luaSocketPath: "",
      environment: SharedPathDefaults.defaultLuaEnvironment,
      watchConfigFile: true,
      lockDirectory: "",
      widgetEditorStubPath: "",
      develop: false,
      luaCommandLimits: .init(
        timeoutSeconds: 5,
        maxOutputBytes: 64 * 1024,
        maxAsyncJobs: 8
      )
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
    themeSection = .default
    barSection = .default

    resetDerivedDefaults()

    do {
      try load()
      loadFailureState = nil
    } catch {
      let message = "invalid config at \(configPath): \(error)"
      fputs("easybar: \(message)\n", stderr)
      loadFailureState = LoadFailureState(error: error, context: .initialLoad)
    }
  }

  /// Reloads config from disk and returns one validation error when reload fails.
  @discardableResult
  func reload() -> (any Error)? {
    let snapshot = snapshot()
    resetToDefaults()

    do {
      try load()
      loadFailureState = nil
      objectWillChange.send()
      return nil
    } catch {
      apply(snapshot)
      loadFailureState = LoadFailureState(error: error, context: .reloadKeptPreviousConfig)
      objectWillChange.send()
      return error
    }
  }

  /// Absolute path to the active config file.
  var configPath: String {
    if let override = environmentConfigPathOverride() {
      return override
    }

    return SharedPathDefaults.defaultConfigPath().path
  }

  /// Restores all defaults before parsing again.
  func resetToDefaults() {
    resetStaticDefaults()
    resetDerivedDefaults()
  }

  /// Restores theme defaults.
  func resetThemeDefaults() {
    themeSection = .default
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
