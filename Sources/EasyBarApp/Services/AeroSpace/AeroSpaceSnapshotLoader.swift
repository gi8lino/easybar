import EasyBarShared
import Foundation

/// One resolved snapshot of AeroSpace state.
struct AeroSpaceSnapshot {
  /// Workspace items to publish.
  let spaces: [SpaceItem]
  /// Focused application when known.
  let focusedApp: SpaceApp?
  /// Focused window layout mode.
  let focusedLayoutMode: AeroSpaceLayoutMode
}

/// Loads and parses AeroSpace CLI output into app-ready state.
enum AeroSpaceSnapshotLoader {
  /// Reads the current AeroSpace snapshot.
  static func load(
    run: @escaping ([String]) -> String?,
    resolveAppID: (String, String?) -> String,
    logger: ProcessLogger? = nil
  ) -> AeroSpaceSnapshot {
    let jsonProvider = JSONAeroSpaceSnapshotProvider(run: run)

    do {
      return try buildSnapshot(
        state: jsonProvider.loadState(),
        resolveAppID: resolveAppID
      )
    } catch {
      logger?.warn(
        "aerospace JSON snapshot unavailable; falling back to text output",
        .field("error", error)
      )
    }

    let textProvider = TextAeroSpaceSnapshotProvider(run: run)

    do {
      return try buildSnapshot(
        state: textProvider.loadState(),
        resolveAppID: resolveAppID
      )
    } catch {
      logger?.warn(
        "aerospace text snapshot unavailable",
        .field("error", error)
      )
      return AeroSpaceSnapshot(spaces: [], focusedApp: nil, focusedLayoutMode: .unknown)
    }
  }

  /// Builds app-facing state from provider-neutral AeroSpace state.
  private static func buildSnapshot(
    state: AeroSpaceRawSnapshot,
    resolveAppID: (String, String?) -> String
  ) -> AeroSpaceSnapshot {
    let groupedApps = Dictionary(grouping: state.windows, by: \.workspace)

    let spaces =
      state.workspaces
      .map { workspace in
        SpaceItem(
          id: workspace.name,
          name: workspace.name,
          isFocused: workspace.isFocused,
          isVisible: workspace.isVisible,
          apps: deduplicateApps(groupedApps[workspace.name] ?? [], resolveAppID: resolveAppID)
        )
      }

    return AeroSpaceSnapshot(
      spaces: spaces,
      focusedApp: makeFocusedApp(state.focusedWindow, resolveAppID: resolveAppID),
      focusedLayoutMode: parseLayoutMode(state.focusedLayout)
    )
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
      result.append(
        makeSpaceApp(name: window.name, bundlePath: window.bundlePath, resolveAppID: resolveAppID))
    }

    return result
  }

  /// Builds the focused app from parsed AeroSpace window data.
  private static func makeFocusedApp(
    _ window: FocusedWindowDTO?,
    resolveAppID: (String, String?) -> String
  ) -> SpaceApp? {
    guard let window else { return nil }

    let bundlePath = window.bundlePath.isEmpty ? nil : window.bundlePath
    let id = resolveAppID(window.name, bundlePath)

    guard !id.isEmpty else { return nil }

    return SpaceApp(
      id: id,
      bundleID: "",
      name: window.name,
      bundlePath: bundlePath
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

/// Source of raw AeroSpace snapshot data.
private protocol AeroSpaceSnapshotProvider {
  /// Loads one raw AeroSpace snapshot.
  func loadState() throws -> AeroSpaceRawSnapshot
}

/// Loads AeroSpace state from modern JSON CLI output.
private struct JSONAeroSpaceSnapshotProvider: AeroSpaceSnapshotProvider {
  let run: ([String]) -> String?

  func loadState() throws -> AeroSpaceRawSnapshot {
    let workspacesOutput = try requireOutput(
      run(["list-workspaces", "--all", "--json"]),
      command: "list-workspaces --all --json"
    )
    let windowsOutput = try requireOutput(
      run(["list-windows", "--all", "--json"]),
      command: "list-windows --all --json"
    )
    let focusedWindowOutput = run(["list-windows", "--focused", "--json"])

    let decoder = JSONDecoder()
    let workspaces = try decode([JSONWorkspaceDTO].self, from: workspacesOutput, decoder: decoder)
      .map {
        WorkspaceDTO(
          name: $0.workspace,
          isFocused: $0.workspaceIsFocused,
          isVisible: $0.workspaceIsVisible
        )
      }
    let windows = try decode([JSONWindowDTO].self, from: windowsOutput, decoder: decoder)
      .map {
        WindowDTO(
          workspace: $0.workspace,
          name: $0.appName,
          bundlePath: $0.appBundlePath ?? ""
        )
      }
    let focusedWindows =
      try focusedWindowOutput.map {
        try decodeWindowList(from: $0, decoder: decoder)
      } ?? []
    let focusedWindow = focusedWindows.first.map {
      FocusedWindowDTO(
        name: $0.appName,
        bundlePath: $0.appBundlePath ?? ""
      )
    }
    let focusedLayout = focusedWindows.first?.windowLayout ?? ""

    return AeroSpaceRawSnapshot(
      workspaces: workspaces,
      windows: windows,
      focusedWindow: focusedWindow,
      focusedLayout: focusedLayout
    )
  }

  /// Decodes either the expected array or a single object for defensive compatibility.
  private func decodeWindowList(
    from output: String,
    decoder: JSONDecoder
  ) throws -> [JSONWindowDTO] {
    do {
      return try decode([JSONWindowDTO].self, from: output, decoder: decoder)
    } catch {
      return [try decode(JSONWindowDTO.self, from: output, decoder: decoder)]
    }
  }

  /// Decodes one JSON payload.
  private func decode<T: Decodable>(
    _ type: T.Type,
    from output: String,
    decoder: JSONDecoder
  ) throws -> T {
    guard let data = output.data(using: .utf8) else {
      throw AeroSpaceSnapshotProviderError.invalidUTF8
    }

    do {
      return try decoder.decode(type, from: data)
    } catch {
      throw AeroSpaceSnapshotProviderError.decodeFailed(command: "json", error: error)
    }
  }
}

/// Loads AeroSpace state from legacy custom `--format` text output.
private struct TextAeroSpaceSnapshotProvider: AeroSpaceSnapshotProvider {
  let run: ([String]) -> String?

  func loadState() throws -> AeroSpaceRawSnapshot {
    let workspaces = loadWorkspaces()
    let windows = loadWindows()

    return AeroSpaceRawSnapshot(
      workspaces: workspaces,
      windows: windows,
      focusedWindow: loadFocusedApp(),
      focusedLayout: loadFocusedLayoutMode()
    )
  }

  /// Reads all known workspaces from AeroSpace.
  private func loadWorkspaces() -> [WorkspaceDTO] {
    guard
      let namesOutput = run([
        "list-workspaces", "--all", "--format", "%{workspace}",
      ]),
      let stateOutput = run([
        "list-workspaces",
        "--all",
        "--format",
        "%{workspace} | %{workspace-is-focused} | %{workspace-is-visible}",
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
  private func loadWindows() -> [WindowDTO] {
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
  private func loadFocusedApp() -> FocusedWindowDTO? {
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
    let bundlePath = parts.first ?? ""
    let name = parts.count > 1 ? parts[1] : ""

    return FocusedWindowDTO(name: name, bundlePath: bundlePath)
  }

  /// Reads the currently focused AeroSpace layout mode.
  private func loadFocusedLayoutMode() -> String {
    return run([
      "list-windows",
      "--focused",
      "--format",
      "%{window-layout}",
    ]) ?? ""
  }

  /// Parses one workspace state line from AeroSpace output.
  private func parseWorkspaceStateLine(_ line: Substring) -> (String, WorkspaceState)? {
    let parts = splitPipedLine(String(line))
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
  private func parseWindowLine(_ line: Substring) -> WindowDTO? {
    let parts = splitPipedLine(String(line))
    guard parts.count >= 3 else { return nil }

    return WindowDTO(
      workspace: parts[0],
      name: parts[1],
      bundlePath: parts[2]
    )
  }

  /// Splits one `a | b | c` line and trims each part.
  private func splitPipedLine(_ line: String) -> [String] {
    line
      .components(separatedBy: " | ")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }
}

/// Requires command output from a provider command.
private func requireOutput(_ output: String?, command: String) throws -> String {
  guard let output else {
    throw AeroSpaceSnapshotProviderError.commandFailed(command: command)
  }

  return output
}

/// Raw provider-neutral AeroSpace state.
private struct AeroSpaceRawSnapshot {
  let workspaces: [WorkspaceDTO]
  let windows: [WindowDTO]
  let focusedWindow: FocusedWindowDTO?
  let focusedLayout: String
}

/// Raw workspace state parsed from AeroSpace output.
private struct WorkspaceDTO {
  /// Workspace name.
  let name: String
  /// Whether the workspace is focused.
  let isFocused: Bool
  /// Whether the workspace is visible.
  let isVisible: Bool
}

/// Focus and visibility flags for one workspace.
private struct WorkspaceState {
  /// Whether the workspace is focused.
  let isFocused: Bool
  /// Whether the workspace is visible.
  let isVisible: Bool

  /// Default workspace state when AeroSpace state output is missing.
  static let `default` = WorkspaceState(
    isFocused: false,
    isVisible: false
  )
}

/// Raw window state parsed from AeroSpace output.
private struct WindowDTO {
  /// Workspace containing the window.
  let workspace: String
  /// App name.
  let name: String
  /// App bundle path reported for the window.
  let bundlePath: String
}

/// Raw focused window state parsed from AeroSpace output.
private struct FocusedWindowDTO {
  /// App name.
  let name: String
  /// App bundle path reported for the window.
  let bundlePath: String
}

/// JSON workspace shape returned by `aerospace list-workspaces --json`.
private struct JSONWorkspaceDTO: Decodable {
  let workspace: String
  let workspaceIsFocused: Bool
  let workspaceIsVisible: Bool

  enum CodingKeys: String, CodingKey {
    case workspace
    case workspaceIsFocused = "workspace-is-focused"
    case workspaceIsVisible = "workspace-is-visible"
  }
}

/// JSON window shape returned by `aerospace list-windows --json`.
private struct JSONWindowDTO: Decodable {
  let workspace: String
  let appName: String
  let appBundlePath: String?
  let windowLayout: String?

  enum CodingKeys: String, CodingKey {
    case workspace
    case appName = "app-name"
    case appBundlePath = "app-bundle-path"
    case windowLayout = "window-layout"
  }
}

/// Snapshot provider failures used for fallback diagnostics.
private enum AeroSpaceSnapshotProviderError: Error, CustomStringConvertible {
  case commandFailed(command: String)
  case invalidUTF8
  case decodeFailed(command: String, error: Error)

  var description: String {
    switch self {
    case .commandFailed(let command):
      return "command failed: \(command)"
    case .invalidUTF8:
      return "invalid UTF-8 output"
    case .decodeFailed(let command, let error):
      return "failed to decode \(command) output: \(error)"
    }
  }
}
