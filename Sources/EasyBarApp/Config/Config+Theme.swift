import EasyBarCalendarConfig
import Foundation
import TOMLKit

extension Config {

  /// Parses the selected theme, loads its TOML file, and applies inline color overrides.
  func parseTheme(from toml: TOMLTable) throws {
    let currentTheme = themeSection
    let themeTable = toml["theme"]?.table

    let selectedName: String
    let configuredThemesDir: String?
    let overridesTable: TOMLTable

    if let themeTable {
      selectedName =
        try optionalString(themeTable["name"], path: "theme.name")
        ?? currentTheme.name

      configuredThemesDir = try optionalExpandedPath(
        themeTable["themes_dir"],
        path: "theme.themes_dir"
      )

      overridesTable = themeTable["colors"]?.table ?? TOMLTable()
    } else {
      selectedName = currentTheme.name
      configuredThemesDir = nil
      overridesTable = TOMLTable()
    }

    let resolvedThemesDir = configuredThemesDir ?? currentTheme.themesDir
    let fileColors = try loadThemeColors(
      named: selectedName,
      themesDir: resolvedThemesDir
    )

    let colors = try parseThemeColorOverrides(
      from: overridesTable,
      path: "theme.colors",
      fallback: fileColors
    )

    themeSection = ThemeSection(
      name: normalizedThemeName(selectedName),
      themesDir: resolvedThemesDir,
      colors: colors
    )

    registerDirectoryRequirement(
      for: "theme.themes_dir",
      path: resolvedThemesDir,
      kind: .directory
    )
  }

  /// Applies the selected theme as defaults before user widget config is parsed.
  func applyThemeDefaults() {
    applyThemeBarDefaults()
    applyThemeBuiltinDefaults()
  }

  /// Resolves a color reference such as `theme.text`.
  func resolveThemeColorHex(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let prefix = "theme."

    guard trimmed.lowercased().hasPrefix(prefix) else {
      return nil
    }

    let token = String(trimmed.dropFirst(prefix.count))
    return themeColorHex(named: token)
  }

  /// Resolves a theme token without the `theme.` prefix.
  func themeColorHex(named token: String) -> String? {
    guard let themeToken = ThemeColorToken(normalizedToken: normalizedThemeToken(token)) else {
      return nil
    }

    return themeColors[themeToken]
  }

  /// Returns the default native group style derived from the active theme.
  func defaultBuiltinGroupStyle() -> BuiltinWidgetStyle {
    BuiltinWidgetStyle(
      icon: "",
      textColorHex: nil,
      backgroundColorHex: themeSurfaceHex,
      borderColorHex: themeBorderColorHex,
      borderWidth: 1,
      cornerRadius: 8,
      marginX: 0,
      marginY: 0,
      paddingX: 8,
      paddingY: 4,
      spacing: 6,
      opacity: 1
    )
  }
}

extension Config {
  /// Applies the standard transparent built-in chrome.
  private func applyTransparentBuiltinStyle(
    _ style: inout BuiltinWidgetStyle,
    textColorHex: String? = nil
  ) {
    style.textColorHex = textColorHex ?? themeTextColorHex
    style.backgroundColorHex = themeTransparentColorHex
    style.borderColorHex = themeTransparentColorHex
  }

  /// Applies the standard surface-style built-in chrome.
  private func applySurfaceBuiltinStyle(
    _ style: inout BuiltinWidgetStyle,
    textColorHex: String? = nil
  ) {
    style.textColorHex = textColorHex ?? themeTextColorHex
    style.backgroundColorHex = themeSurfaceHex
    style.borderColorHex = themeBorderColorHex
  }

  /// Applies theme defaults to the bar.
  private func applyThemeBarDefaults() {
    barSection.backgroundHex = themeBackgroundHex
    barSection.borderHex = themeTransparentColorHex
  }

  /// Applies component-specific theme defaults to every native built-in.
  private func applyThemeBuiltinDefaults() {
    applyThemeCPUSparklineDefaults()
    applyThemeBatteryDefaults()
    applyThemeSpacesDefaults()
    applyThemeFrontAppDefaults()
    applyThemeAeroSpaceModeDefaults()
    applyThemeVolumeDefaults()
    applyThemeWiFiDefaults()
    applyThemeCalendarDefaults()
    applyThemeTimeDefaults()
    applyThemeDateDefaults()
  }

  /// Applies theme defaults to the CPU built-in.
  private func applyThemeCPUSparklineDefaults() {
    applyTransparentBuiltinStyle(&builtinCPU.style)
    builtinCPU.colorHex = themeSuccessSecondaryColorHex
  }

  /// Applies theme defaults to the battery built-in.
  private func applyThemeBatteryDefaults() {
    applyTransparentBuiltinStyle(&builtinBattery.style)

    builtinBattery.fixedColorHex = themeTextColorHex
    builtinBattery.colors.highColorHex = themeSuccessColorHex
    builtinBattery.colors.mediumColorHex = themeWarningColorHex
    builtinBattery.colors.lowColorHex = themeOrangeColorHex
    builtinBattery.colors.criticalColorHex = themeDangerColorHex
    builtinBattery.colors.frameColorHex = themeMutedColorHex
    builtinBattery.colors.overlayOutlineColorHex = themeOverlayOutlineColorHex
    builtinBattery.colors.chargingOverlayColorHex = themeOverlayTextColorHex
    builtinBattery.colors.externalPowerOverlayColorHex = themeOverlayTextColorHex
    builtinBattery.colors.onHoldOverlayColorHex = themeOverlayTextColorHex
    builtinBattery.colors.unavailableColorHex = themeMutedColorHex

    builtinBattery.popup = defaultBuiltinPopupStyle()
  }

  /// Applies theme defaults to the spaces built-in.
  private func applyThemeSpacesDefaults() {
    applyTransparentBuiltinStyle(&builtinSpaces.style)

    builtinSpaces.text.focusedColorHex = themeTextSecondaryColorHex
    builtinSpaces.text.inactiveColorHex = themeTextSecondaryColorHex

    builtinSpaces.colors.activeBackgroundHex = themeSurfaceElevatedHex
    builtinSpaces.colors.inactiveBackgroundHex = themeSurfaceHex
    builtinSpaces.colors.activeBorderHex = themeBorderStrongColorHex
    builtinSpaces.colors.inactiveBorderHex = themeBorderSubtleColorHex
    builtinSpaces.colors.focusedAppBorderHex = themeBorderSubtleColorHex
  }

  /// Applies theme defaults to the front app built-in.
  private func applyThemeFrontAppDefaults() {
    applySurfaceBuiltinStyle(&builtinFrontApp.style)
  }

  /// Applies theme defaults to the AeroSpace mode built-in.
  private func applyThemeAeroSpaceModeDefaults() {
    applySurfaceBuiltinStyle(&builtinAeroSpaceMode.style)
  }

  /// Applies theme defaults to the volume built-in.
  private func applyThemeVolumeDefaults() {
    applyTransparentBuiltinStyle(&builtinVolume.style)
  }

  /// Applies theme defaults to the Wi-Fi built-in.
  private func applyThemeWiFiDefaults() {
    applyTransparentBuiltinStyle(&builtinWiFi.style)

    builtinWiFi.activeColorHex = themeTextColorHex
    builtinWiFi.inactiveColorHex = themeMutedColorHex
    builtinWiFi.inlineTextColorHex = themeTextColorHex
    builtinWiFi.popup = defaultBuiltinPopupStyle()
  }

  /// Applies theme defaults to the calendar built-in.
  private func applyThemeCalendarDefaults() {
    applyThemeCalendarAnchorDefaults()
    applyThemeCalendarAppointmentDefaults()
    applyThemeCalendarBirthdayDefaults()
    applyThemeCalendarComposerDefaults()
    applyThemeCalendarUpcomingDefaults()
    applyThemeCalendarMonthDefaults()
  }

  /// Applies theme defaults to the calendar bar anchor.
  private func applyThemeCalendarAnchorDefaults() {
    builtinCalendar.style.textColorHex = themeTextColorHex
    builtinCalendar.style.backgroundColorHex = themeSurfaceHex
    builtinCalendar.style.borderColorHex = themeBorderColorHex

    builtinCalendar.anchor.topTextColorHex = themeTextColorHex
    builtinCalendar.anchor.bottomTextColorHex = themeMutedColorHex
  }

  /// Applies theme defaults to calendar appointment rows.
  private func applyThemeCalendarAppointmentDefaults() {
    builtinCalendar.appointments.eventTextColorHex = themeTextColorHex
    builtinCalendar.appointments.emptyTextColorHex = themeMutedColorHex
    builtinCalendar.appointments.secondaryTextColorHex = themeAccentSecondaryColorHex
    builtinCalendar.appointments.travelTextColorHex = themeMutedSecondaryColorHex
    builtinCalendar.appointments.travelIconColorHex = themeMutedSecondaryColorHex
    builtinCalendar.appointments.alertIconColorHex = themeWarningColorHex
  }

  /// Applies theme defaults to calendar birthday indicators.
  private func applyThemeCalendarBirthdayDefaults() {
    builtinCalendar.birthdays.birthdayIconColorHex = themeAccentSoftColorHex
  }

  /// Applies theme defaults to the calendar event composer.
  private func applyThemeCalendarComposerDefaults() {
    builtinCalendar.composer.style.backgroundColorHex = themeBackgroundHex
    builtinCalendar.composer.style.borderColorHex = themeBorderColorHex
    builtinCalendar.composer.style.headerTextColorHex = themeTextColorHex
  }

  /// Applies theme defaults to the upcoming calendar popup.
  private func applyThemeCalendarUpcomingDefaults() {
    builtinCalendar.upcoming.popup.backgroundColorHex = themeBackgroundHex
    builtinCalendar.upcoming.popup.borderColorHex = themeBorderColorHex
  }

  /// Applies theme defaults to the month calendar popup.
  private func applyThemeCalendarMonthDefaults() {
    builtinCalendar.month.popup.style.backgroundColorHex = themeBackgroundHex
    builtinCalendar.month.popup.style.borderColorHex = themeBorderStrongColorHex

    builtinCalendar.month.popup.calendar.headerTextColorHex = themeTextColorHex
    builtinCalendar.month.popup.calendar.weekdayTextColorHex = themeAccentColorHex
    builtinCalendar.month.popup.calendar.dayTextColorHex = themeTextColorHex
    builtinCalendar.month.popup.calendar.outsideMonthTextColorHex = themeOutsideMonthColorHex
    builtinCalendar.month.popup.calendar.todayCellBackgroundColorHex = themeTransparentColorHex
    builtinCalendar.month.popup.calendar.todayCellBorderColorHex = themeDangerColorHex
    builtinCalendar.month.popup.calendar.indicatorColorHex = themeSuccessSecondaryColorHex

    builtinCalendar.month.popup.selection.selectedTextColorHex = themeSelectionTextColorHex
    builtinCalendar.month.popup.selection.selectedBackgroundColorHex = themeSelectionBackgroundColorHex

    builtinCalendar.month.popup.anchor.textColorHex = themeTextColorHex
    builtinCalendar.month.popup.todayButton.borderColorHex = themeTodayButtonBorderColorHex
  }

  /// Applies theme defaults to the time built-in.
  private func applyThemeTimeDefaults() {
    applySurfaceBuiltinStyle(&builtinTime.style)
  }

  /// Applies theme defaults to the date built-in.
  private func applyThemeDateDefaults() {
    applySurfaceBuiltinStyle(&builtinDate.style)
  }

  /// Returns the default tooltip popup style derived from the active theme.
  private func defaultBuiltinPopupStyle() -> BuiltinPopupStyle {
    BuiltinPopupStyle(
      textColorHex: themeTextSecondaryColorHex,
      backgroundColorHex: themeBackgroundHex,
      borderColorHex: themeBorderStrongColorHex,
      borderWidth: Self.builtinPopupDefaultBorderWidth,
      cornerRadius: Self.builtinPopupDefaultCornerRadius,
      paddingX: Self.builtinPopupDefaultPaddingX,
      paddingY: Self.builtinPopupDefaultPaddingY,
      marginX: Self.builtinPopupDefaultMarginX,
      marginY: Self.builtinPopupDefaultMarginY
    )
  }
}

extension Config {

  /// Loads theme colors from the user themes directory or bundled resources.
  private func loadThemeColors(
    named name: String,
    themesDir: String
  ) throws -> ThemeColors {
    let fileName = try themeFileName(for: name)
    let fileManager = FileManager.default

    if let userThemeURL = userThemeURL(fileName: fileName, themesDir: themesDir),
      fileManager.fileExists(atPath: userThemeURL.path)
    {
      return try loadThemeFile(
        at: userThemeURL,
        path: "theme.themes_dir.\(fileName).toml"
      )
    }

    for bundledThemeURL in bundledThemeCandidateURLs(fileName: fileName) {
      guard fileManager.fileExists(atPath: bundledThemeURL.path) else {
        continue
      }

      return try loadThemeFile(
        at: bundledThemeURL,
        path: "bundled theme \(fileName).toml"
      )
    }

    throw ConfigError.invalidValue(
      path: "theme.name",
      message: "theme '\(name)' was not found in \(themesDir) or bundled themes"
    )
  }

  /// Returns all bundled and development theme lookup candidates for one theme file.
  private func bundledThemeCandidateURLs(fileName: String) -> [URL] {
    var candidates: [URL] = []

    if let moduleThemeURL = Bundle.module.url(
      forResource: fileName,
      withExtension: "toml",
      subdirectory: "Themes"
    ) {
      candidates.append(moduleThemeURL)
    }

    if let resourceURL = Bundle.main.resourceURL {
      candidates.append(
        resourceURL
          .appendingPathComponent("Themes", isDirectory: true)
          .appendingPathComponent("\(fileName).toml")
      )
    }

    if let executableURL = Bundle.main.executableURL {
      let executableDirectory = executableURL.deletingLastPathComponent()

      candidates.append(
        executableDirectory
          .deletingLastPathComponent()
          .appendingPathComponent("Resources", isDirectory: true)
          .appendingPathComponent("Themes", isDirectory: true)
          .appendingPathComponent("\(fileName).toml")
      )

      candidates.append(
        executableDirectory
          .appendingPathComponent("Themes", isDirectory: true)
          .appendingPathComponent("\(fileName).toml")
      )
    }

    candidates.append(
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("themes", isDirectory: true)
        .appendingPathComponent("\(fileName).toml")
    )

    return uniqueThemeCandidateURLs(candidates)
  }

  /// Returns theme candidate URLs without duplicate paths.
  private func uniqueThemeCandidateURLs(_ urls: [URL]) -> [URL] {
    var seen: Set<String> = []
    var unique: [URL] = []

    for url in urls {
      let path = url.standardizedFileURL.path
      guard !seen.contains(path) else { continue }
      seen.insert(path)
      unique.append(url)
    }

    return unique
  }

  /// Loads and parses one complete theme TOML file.
  private func loadThemeFile(
    at url: URL,
    path: String
  ) throws -> ThemeColors {
    let text: String

    do {
      text = try String(contentsOf: url, encoding: .utf8)
    } catch {
      throw ConfigError.invalidValue(
        path: path,
        message: "failed to read theme file at \(url.path): \(error.localizedDescription)"
      )
    }

    do {
      let table = try TOMLTable(string: text)

      guard let colors = table["colors"]?.table else {
        throw ConfigError.invalidValue(
          path: "\(path).colors",
          message: "theme file must contain a [colors] table"
        )
      }

      return try parseCompleteThemeColors(
        from: colors,
        path: "\(path).colors"
      )
    } catch let error as TOMLParseError {
      throw ConfigError.invalidValue(
        path: path,
        message: "failed to parse theme TOML at \(url.path): \(error)"
      )
    } catch let error as ConfigError {
      throw error
    } catch {
      throw ConfigError.invalidValue(
        path: path,
        message: "failed to parse theme TOML at \(url.path): \(error)"
      )
    }
  }

  /// Parses a complete theme color table.
  private func parseCompleteThemeColors(
    from table: TOMLTable,
    path: String
  ) throws -> ThemeColors {
    ThemeColors(
      valuesByToken: try Dictionary(
        uniqueKeysWithValues: ThemeColorToken.allCases.map { token in
          (token, try requiredThemeColor(table, token.rawValue, path: path))
        }
      )
    )
  }

  /// Parses optional inline theme color overrides from `config.toml`.
  private func parseThemeColorOverrides(
    from table: TOMLTable,
    path: String,
    fallback: ThemeColors
  ) throws -> ThemeColors {
    ThemeColors(
      valuesByToken: try Dictionary(
        uniqueKeysWithValues: ThemeColorToken.allCases.map { token in
          let value =
            try optionalString(table[token.rawValue], path: "\(path).\(token.rawValue)")
            ?? fallback[token]
          return (token, value)
        }
      )
    )
  }

  /// Returns one required color value from a complete theme file.
  private func requiredThemeColor(
    _ table: TOMLTable,
    _ key: String,
    path: String
  ) throws -> String {
    guard let value = try optionalString(table[key], path: "\(path).\(key)") else {
      throw ConfigError.invalidValue(
        path: "\(path).\(key)",
        message: "missing required theme color '\(key)'"
      )
    }

    return value
  }

  /// Returns the user theme file URL for one theme name.
  private func userThemeURL(
    fileName: String,
    themesDir: String
  ) -> URL? {
    let trimmed = themesDir.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let expanded = NSString(string: trimmed).expandingTildeInPath

    return URL(fileURLWithPath: expanded, isDirectory: true)
      .appendingPathComponent("\(fileName).toml")
  }

  /// Returns the safe file name for one theme.
  private func themeFileName(for name: String) throws -> String {
    let normalized = normalizedThemeName(name)

    guard !normalized.isEmpty else {
      throw ConfigError.invalidValue(
        path: "theme.name",
        message: "theme name must not be empty"
      )
    }

    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
    guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
      throw ConfigError.invalidValue(
        path: "theme.name",
        message: "theme name may only contain letters, numbers, dots, underscores, and dashes"
      )
    }

    return normalized
  }

  /// Normalizes one theme name for lookup.
  private func normalizedThemeName(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  /// Normalizes one theme token for lookup.
  private func normalizedThemeToken(_ token: String) -> String {
    token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
