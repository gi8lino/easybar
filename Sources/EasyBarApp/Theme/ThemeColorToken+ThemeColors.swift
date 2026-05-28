extension Config.ThemeColors {
  /// Creates one theme color set from values keyed by token.
  init(valuesByToken values: [ThemeColorToken: String]) {
    self.init(
      background: values[.background] ?? "",
      surface: values[.surface] ?? "",
      surfaceElevated: values[.surfaceElevated] ?? "",
      surfaceHover: values[.surfaceHover] ?? "",
      text: values[.text] ?? "",
      textSecondary: values[.textSecondary] ?? "",
      textTertiary: values[.textTertiary] ?? "",
      muted: values[.muted] ?? "",
      mutedSecondary: values[.mutedSecondary] ?? "",
      outsideMonth: values[.outsideMonth] ?? "",
      accent: values[.accent] ?? "",
      accentSecondary: values[.accentSecondary] ?? "",
      accentSoft: values[.accentSoft] ?? "",
      success: values[.success] ?? "",
      successSecondary: values[.successSecondary] ?? "",
      warning: values[.warning] ?? "",
      orange: values[.orange] ?? "",
      error: values[.error] ?? "",
      danger: values[.danger] ?? "",
      border: values[.border] ?? "",
      borderStrong: values[.borderStrong] ?? "",
      borderSubtle: values[.borderSubtle] ?? "",
      selectionText: values[.selectionText] ?? "",
      selectionBackground: values[.selectionBackground] ?? "",
      transparent: values[.transparent] ?? "",
      overlayOutline: values[.overlayOutline] ?? "",
      overlayText: values[.overlayText] ?? "",
      todayButtonBorder: values[.todayButtonBorder] ?? ""
    )
  }

  /// Returns one color value for the given token.
  subscript(token: ThemeColorToken) -> String {
    get {
      switch token {
      case .background:
        background
      case .surface:
        surface
      case .surfaceElevated:
        surfaceElevated
      case .surfaceHover:
        surfaceHover
      case .text:
        text
      case .textSecondary:
        textSecondary
      case .textTertiary:
        textTertiary
      case .muted:
        muted
      case .mutedSecondary:
        mutedSecondary
      case .outsideMonth:
        outsideMonth
      case .accent:
        accent
      case .accentSecondary:
        accentSecondary
      case .accentSoft:
        accentSoft
      case .success:
        success
      case .successSecondary:
        successSecondary
      case .warning:
        warning
      case .orange:
        orange
      case .error:
        error
      case .danger:
        danger
      case .border:
        border
      case .borderStrong:
        borderStrong
      case .borderSubtle:
        borderSubtle
      case .selectionText:
        selectionText
      case .selectionBackground:
        selectionBackground
      case .transparent:
        transparent
      case .overlayOutline:
        overlayOutline
      case .overlayText:
        overlayText
      case .todayButtonBorder:
        todayButtonBorder
      }
    }
    set {
      switch token {
      case .background:
        background = newValue
      case .surface:
        surface = newValue
      case .surfaceElevated:
        surfaceElevated = newValue
      case .surfaceHover:
        surfaceHover = newValue
      case .text:
        text = newValue
      case .textSecondary:
        textSecondary = newValue
      case .textTertiary:
        textTertiary = newValue
      case .muted:
        muted = newValue
      case .mutedSecondary:
        mutedSecondary = newValue
      case .outsideMonth:
        outsideMonth = newValue
      case .accent:
        accent = newValue
      case .accentSecondary:
        accentSecondary = newValue
      case .accentSoft:
        accentSoft = newValue
      case .success:
        success = newValue
      case .successSecondary:
        successSecondary = newValue
      case .warning:
        warning = newValue
      case .orange:
        orange = newValue
      case .error:
        error = newValue
      case .danger:
        danger = newValue
      case .border:
        border = newValue
      case .borderStrong:
        borderStrong = newValue
      case .borderSubtle:
        borderSubtle = newValue
      case .selectionText:
        selectionText = newValue
      case .selectionBackground:
        selectionBackground = newValue
      case .transparent:
        transparent = newValue
      case .overlayOutline:
        overlayOutline = newValue
      case .overlayText:
        overlayText = newValue
      case .todayButtonBorder:
        todayButtonBorder = newValue
      }
    }
  }

  /// Returns all colors keyed by their public token names.
  var valuesByName: [String: String] {
    Dictionary(
      uniqueKeysWithValues: ThemeColorToken.allCases.map { token in
        (token.rawValue, self[token])
      }
    )
  }
}
