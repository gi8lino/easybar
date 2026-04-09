import EasyBarShared

extension Config {
  /// Captures the current config state.
  func snapshot() -> ConfigSnapshot {
    ConfigSnapshot(
      app: .init(
        widgetsPath: appSection.widgetsPath,
        luaPath: appSection.luaPath,
        watchConfigFile: appSection.watchConfigFile,
        lockDirectory: appSection.lockDirectory
      ),
      logging: .init(
        enabled: loggingSection.enabled,
        level: loggingSection.level,
        directory: loggingSection.directory
      ),
      calendarAgent: .init(
        enabled: calendarAgentSection.enabled,
        socketPath: calendarAgentSection.socketPath
      ),
      networkAgent: .init(
        enabled: networkAgentSection.enabled,
        socketPath: networkAgentSection.socketPath,
        refreshIntervalSeconds: networkAgentSection.refreshIntervalSeconds,
        allowUnauthorizedNonSensitiveFields:
          networkAgentSection.allowUnauthorizedNonSensitiveFields
      ),
      bar: .init(
        height: barHeight,
        paddingX: barPaddingX,
        extendBehindNotch: barExtendBehindNotch,
        backgroundHex: barBackgroundHex,
        borderHex: barBorderHex
      ),
      builtins: .init(
        cpu: builtinCPU,
        battery: builtinBattery,
        groups: builtinGroups,
        spaces: builtinSpaces,
        frontApp: builtinFrontApp,
        aerospaceMode: builtinAeroSpaceMode,
        volume: builtinVolume,
        wifi: builtinWiFi,
        calendar: builtinCalendar,
        time: builtinTime,
        date: builtinDate
      )
    )
  }

  /// Restores one previous config snapshot.
  func apply(_ snapshot: ConfigSnapshot) {
    applyAppSnapshot(snapshot)
    applyBarSnapshot(snapshot)
    applyBuiltinSnapshot(snapshot)
  }

  /// Restores the app-level config snapshot.
  func applyAppSnapshot(_ snapshot: ConfigSnapshot) {
    appSection = .init(
      widgetsPath: snapshot.app.widgetsPath,
      luaPath: snapshot.app.luaPath,
      watchConfigFile: snapshot.app.watchConfigFile,
      lockDirectory: snapshot.app.lockDirectory
    )

    loggingSection = .init(
      enabled: snapshot.logging.enabled,
      level: snapshot.logging.level,
      directory: snapshot.logging.directory
    )

    calendarAgentSection = .init(
      enabled: snapshot.calendarAgent.enabled,
      socketPath: snapshot.calendarAgent.socketPath
    )

    networkAgentSection = .init(
      enabled: snapshot.networkAgent.enabled,
      socketPath: snapshot.networkAgent.socketPath,
      refreshIntervalSeconds: snapshot.networkAgent.refreshIntervalSeconds,
      allowUnauthorizedNonSensitiveFields:
        snapshot.networkAgent.allowUnauthorizedNonSensitiveFields
    )
  }

  /// Restores the bar config snapshot.
  func applyBarSnapshot(_ snapshot: ConfigSnapshot) {
    barHeight = snapshot.bar.height
    barPaddingX = snapshot.bar.paddingX
    barExtendBehindNotch = snapshot.bar.extendBehindNotch

    barBackgroundHex = snapshot.bar.backgroundHex
    barBorderHex = snapshot.bar.borderHex
  }

  /// Restores the built-in widget config snapshot.
  func applyBuiltinSnapshot(_ snapshot: ConfigSnapshot) {
    builtinCPU = snapshot.builtins.cpu
    builtinBattery = snapshot.builtins.battery
    builtinGroups = snapshot.builtins.groups
    builtinSpaces = snapshot.builtins.spaces
    builtinFrontApp = snapshot.builtins.frontApp
    builtinAeroSpaceMode = snapshot.builtins.aerospaceMode
    builtinVolume = snapshot.builtins.volume
    builtinWiFi = snapshot.builtins.wifi
    builtinCalendar = snapshot.builtins.calendar
    builtinTime = snapshot.builtins.time
    builtinDate = snapshot.builtins.date
  }
}
