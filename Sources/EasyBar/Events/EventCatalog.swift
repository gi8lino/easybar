import Foundation

/// Shared event-name catalog and Lua parity checks.
enum EventCatalog {
  static let forcedEventName = "forced"
  private static let internalAppEventNames: Set<String> = [
    AppEvent.manualRefresh.rawValue,
    AppEvent.intervalTick.rawValue,
  ]

  static let luaTokenEventNames: Set<String> = Set(AppEvent.allCases.map(\.rawValue))
    .subtracting(internalAppEventNames)
    .union(Set(WidgetEvent.allCases.map(\.rawValue)))
    .union([forcedEventName])

  static let luaDriverEventNames: Set<String> = Set(AppEvent.allCases.map(\.rawValue))
    .subtracting(internalAppEventNames)
    .union([forcedEventName])

  /// Verifies that the Lua token file matches the Swift event catalog.
  static func validateLuaDefinitions() {
    let warnings = currentLuaDefinitionWarnings()

    guard !warnings.isEmpty else { return }

    for warning in warnings {
      easybarLog.warn(warning)
    }
  }

  /// Returns human-readable mismatch warnings for the Lua token definitions.
  static func currentLuaDefinitionWarnings() -> [String] {
    guard let catalog = loadGeneratedCatalog() else {
      return [
        "unable to validate generated event catalog parity because Events/event_catalog.json could not be loaded"
      ]
    }

    var warnings: [String] = []
    appendMismatchWarnings(
      label: "generated lua event tokens",
      expected: luaTokenEventNames,
      actual: catalog.luaTokenNames,
      warnings: &warnings
    )
    appendMismatchWarnings(
      label: "generated lua driver events",
      expected: luaDriverEventNames,
      actual: catalog.luaDriverNames,
      warnings: &warnings
    )
    appendMismatchWarnings(
      label: "generated mouse buttons",
      expected: Set(MouseButton.allCases.map(\.rawValue)),
      actual: catalog.mouseButtons,
      warnings: &warnings
    )
    appendMismatchWarnings(
      label: "generated scroll directions",
      expected: Set(ScrollDirection.allCases.map(\.rawValue)),
      actual: catalog.scrollDirections,
      warnings: &warnings
    )
    return warnings
  }

  /// Loads the bundled generated event catalog manifest.
  private static func loadGeneratedCatalog() -> GeneratedCatalog? {
    guard
      let url = Bundle.module.url(
        forResource: "event_catalog",
        withExtension: "json",
        subdirectory: "Events"
      ),
      let data = try? Data(contentsOf: url),
      let catalog = try? JSONDecoder().decode(GeneratedCatalogManifest.self, from: data)
    else {
      return nil
    }

    let tokenNames = Set(
      [catalog.forcedEvent.runtimeName]
        + catalog.appEvents.map(\.runtimeName)
        + catalog.widgetGroups.flatMap(\.events).map(\.runtimeName)
    )

    let driverNames = Set(
      [catalog.forcedEvent.runtimeName]
        + catalog.appEvents.filter(\.driver).map(\.runtimeName)
    )

    return GeneratedCatalog(
      luaTokenNames: tokenNames,
      luaDriverNames: driverNames,
      mouseButtons: Set(catalog.mouseButtons),
      scrollDirections: Set(catalog.scrollDirections)
    )
  }

  /// Appends missing and unexpected event-name warnings for one Lua definition set.
  private static func appendMismatchWarnings(
    label: String,
    expected: Set<String>,
    actual: Set<String>,
    warnings: inout [String]
  ) {
    let missing = expected.subtracting(actual).sorted()
    let unexpected = actual.subtracting(expected).sorted()

    if !missing.isEmpty {
      warnings.append("\(label) missing Swift-defined names: \(missing.joined(separator: ", "))")
    }

    if !unexpected.isEmpty {
      warnings.append(
        "\(label) contain names missing from Swift: \(unexpected.joined(separator: ", "))")
    }
  }
}

private struct GeneratedCatalog {
  let luaTokenNames: Set<String>
  let luaDriverNames: Set<String>
  let mouseButtons: Set<String>
  let scrollDirections: Set<String>
}

private struct GeneratedCatalogManifest: Decodable {
  let forcedEvent: GeneratedCatalogEvent
  let appEvents: [GeneratedCatalogEvent]
  let widgetGroups: [GeneratedCatalogWidgetGroup]
  let mouseButtons: [String]
  let scrollDirections: [String]
}

private struct GeneratedCatalogWidgetGroup: Decodable {
  let events: [GeneratedCatalogEvent]
}

private struct GeneratedCatalogEvent: Decodable {
  let runtimeName: String
  let driver: Bool

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    runtimeName = try container.decode(String.self, forKey: .runtimeName)
    driver = try container.decodeIfPresent(Bool.self, forKey: .driver) ?? false
  }

  private enum CodingKeys: String, CodingKey {
    case runtimeName
    case driver
  }
}
