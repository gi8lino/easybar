import Foundation

/// One resolved snapshot of AeroSpace state.
struct AeroSpaceSnapshot {
  let spaces: [SpaceItem]
  let focusedApp: SpaceApp?
  let focusedLayoutMode: AeroSpaceLayoutMode
}

/// Loads and parses AeroSpace CLI output into app-ready state.
enum AeroSpaceSnapshotLoader {
  /// Reads the current AeroSpace snapshot.
  static func load(
    run: ([String]) -> String?,
    resolveAppID: (String, String?) -> String
  ) -> AeroSpaceSnapshot {
    let workspaces = loadWorkspaces(run: run)
    let windows = loadWindows(run: run)
    let groupedApps = Dictionary(grouping: windows, by: \.workspace)

    let spaces =
      workspaces
      .map { workspace in
        SpaceItem(
          id: workspace.name,
          name: workspace.name,
          isFocused: workspace.isFocused,
          isVisible: workspace.isVisible,
          apps: deduplicateApps(groupedApps[workspace.name] ?? [], resolveAppID: resolveAppID)
        )
      }
      .filter { !$0.apps.isEmpty }

    return AeroSpaceSnapshot(
      spaces: spaces,
      focusedApp: loadFocusedApp(run: run, resolveAppID: resolveAppID),
      focusedLayoutMode: loadFocusedLayoutMode(run: run)
    )
  }

  /// Reads all known workspaces from AeroSpace.
  private static func loadWorkspaces(run: ([String]) -> String?) -> [WorkspaceDTO] {
    guard
      let namesOutput = run([
        "list-workspaces", "--all", "--format", "%{workspace}",
      ]),
      let stateOutput = run([
        "list-workspaces",
        "--all",
        "--format",
        "%{workspace} %{workspace-is-focused} %{workspace-is-visible}",
      ])
    else {
      return []
    }

    let names =
      namesOutput
      .split(whereSeparator: \.isNewline)
      .map(String.init)

    let stateByWorkspace = Dictionary(
      uniqueKeysWithValues:
        stateOutput
        .split(whereSeparator: \.isNewline)
        .compactMap(parseWorkspaceStateLine)
    )

    return names.map { name in
      let state = stateByWorkspace[name] ?? .default

      return WorkspaceDTO(
        name: name,
        isFocused: state.isFocused,
        isVisible: state.isVisible
      )
    }
  }

  /// Reads all windows from AeroSpace.
  private static func loadWindows(run: ([String]) -> String?) -> [WindowDTO] {
    guard
      let output = run([
        "list-windows",
        "--all",
        "--format",
        "%{workspace} | %{app-name} | %{app-bundle-path}",
      ])
    else {
      return []
    }

    return
      output
      .split(whereSeparator: \.isNewline)
      .compactMap(parseWindowLine)
  }

  /// Reads the currently focused app from AeroSpace.
  private static func loadFocusedApp(
    run: ([String]) -> String?,
    resolveAppID: (String, String?) -> String
  ) -> SpaceApp? {
    guard
      let output = run([
        "list-windows",
        "--focused",
        "--format",
        "%{app-bundle-path} | %{app-name}",
      ])
    else {
      return nil
    }

    let parts = splitPipedLine(output)
    let bundlePath = parts.first.flatMap { $0.isEmpty ? nil : $0 }
    let name = parts.count > 1 ? parts[1] : ""
    let id = resolveAppID(name, bundlePath)

    guard !id.isEmpty else { return nil }

    return SpaceApp(
      id: id,
      bundleID: "",
      name: name,
      bundlePath: bundlePath
    )
  }

  /// Reads the currently focused AeroSpace layout mode.
  private static func loadFocusedLayoutMode(run: ([String]) -> String?) -> AeroSpaceLayoutMode {
    guard
      let output = run([
        "list-windows",
        "--focused",
        "--format",
        "%{window-layout}",
      ])
    else {
      return .unknown
    }

    return parseLayoutMode(output)
  }

  /// Deduplicates apps per workspace.
  private static func deduplicateApps(
    _ windows: [WindowDTO],
    resolveAppID: (String, String?) -> String
  ) -> [SpaceApp] {
    var seen = Set<String>()
    var result: [SpaceApp] = []

    for window in windows {
      let key = resolveAppID(
        window.name,
        window.bundlePath.isEmpty ? nil : window.bundlePath
      )
      guard !seen.contains(key) else { continue }

      seen.insert(key)
      result.append(makeSpaceApp(name: window.name, bundlePath: window.bundlePath, resolveAppID: resolveAppID))
    }

    return result
  }

  /// Parses one workspace state line from AeroSpace output.
  private static func parseWorkspaceStateLine(_ line: Substring) -> (String, WorkspaceState)? {
    let parts = line.split(separator: " ").map(String.init)
    guard parts.count >= 3 else { return nil }

    return (
      parts[0],
      WorkspaceState(
        isFocused: parts[1] == "true",
        isVisible: parts[2] == "true"
      )
    )
  }

  /// Parses one window line from AeroSpace output.
  private static func parseWindowLine(_ line: Substring) -> WindowDTO? {
    let parts = splitPipedLine(String(line))
    guard parts.count >= 3 else { return nil }

    return WindowDTO(
      workspace: parts[0],
      name: parts[1],
      bundlePath: parts[2]
    )
  }

  /// Parses one focused layout mode from AeroSpace output.
  private static func parseLayoutMode(_ output: String) -> AeroSpaceLayoutMode {
    let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)

    switch normalized {
    case AeroSpaceLayoutMode.hTiles.rawValue:
      return .hTiles
    case AeroSpaceLayoutMode.vTiles.rawValue:
      return .vTiles
    case AeroSpaceLayoutMode.hAccordion.rawValue:
      return .hAccordion
    case AeroSpaceLayoutMode.vAccordion.rawValue:
      return .vAccordion
    case AeroSpaceLayoutMode.floating.rawValue:
      return .floating
    default:
      return .unknown
    }
  }

  /// Splits one `a | b | c` line and trims each part.
  private static func splitPipedLine(_ line: String) -> [String] {
    line
      .components(separatedBy: " | ")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  /// Builds one `SpaceApp` from parsed AeroSpace window data.
  private static func makeSpaceApp(
    name: String,
    bundlePath: String,
    resolveAppID: (String, String?) -> String
  ) -> SpaceApp {
    let normalizedBundlePath = bundlePath.isEmpty ? nil : bundlePath

    return SpaceApp(
      id: resolveAppID(name, normalizedBundlePath),
      bundleID: "",
      name: name,
      bundlePath: normalizedBundlePath
    )
  }
}

private struct WorkspaceDTO {
  let name: String
  let isFocused: Bool
  let isVisible: Bool
}

private struct WorkspaceState {
  let isFocused: Bool
  let isVisible: Bool

  static let `default` = WorkspaceState(
    isFocused: false,
    isVisible: false
  )
}

private struct WindowDTO {
  let workspace: String
  let name: String
  let bundlePath: String
}
