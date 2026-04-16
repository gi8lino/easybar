import AppKit
import Foundation

/// Loads workspace and focused-app state from AeroSpace.
///
/// Widgets can register themselves as consumers so AeroSpace refresh work only
/// runs when at least one native widget depends on that state.
final class AeroSpaceService: ObservableObject {
  static let shared = AeroSpaceService()

  @Published private(set) var spaces: [SpaceItem] = []
  @Published private(set) var focusedAppID: String?

  /// Resolved focused app used by `FrontAppNativeWidget`.
  @Published private(set) var focusedApp: SpaceApp?

  /// Resolved layout mode used by `AeroSpaceModeNativeWidget`.
  @Published private(set) var focusedLayoutMode: AeroSpaceLayoutMode = .unknown

  private let refreshQueue = DispatchQueue(label: "easybar.aerospace.refresh", qos: .userInitiated)
  private let stateLock = NSLock()
  private var consumers = Set<String>()
  private var appSwitchObserver: NSObjectProtocol?
  private var running = false
  private var generation: UInt64 = 0

  private init() {}
}

// MARK: - Public API

extension AeroSpaceService {
  /// Returns whether any native widget currently needs AeroSpace state.
  private var hasConsumers: Bool {
    !consumers.isEmpty
  }

  /// Starts the service.
  func start() {
    let shouldStart = withLock { () -> Bool in
      guard !running else { return false }
      running = true
      generation &+= 1
      return true
    }

    guard shouldStart else { return }

    easybarLog.debug("aerospace service start begin")
    subscribeAppSwitches()
    refresh()
    easybarLog.debug("aerospace service start end")
  }

  /// Stops the service and prevents queued refresh work from publishing.
  func stop() {
    let observer = withLock { () -> NSObjectProtocol? in
      guard running else { return nil }
      running = false
      generation &+= 1
      return appSwitchObserver
    }

    if let observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
      withLock {
        appSwitchObserver = nil
      }
    }

    easybarLog.debug("aerospace service stop end")
  }

  /// Registers one widget that depends on AeroSpace state.
  func registerConsumer(_ id: String) {
    consumers.insert(id)
    easybarLog.debug("aerospace consumer registered id=\(id) count=\(consumers.count)")
    refresh()
  }

  /// Unregisters one widget that no longer depends on AeroSpace state.
  func unregisterConsumer(_ id: String) {
    consumers.remove(id)
    easybarLog.debug("aerospace consumer unregistered id=\(id) count=\(consumers.count)")
  }

  /// Called by the socket server when an external AeroSpace event occurs.
  func triggerRefresh() {
    guard hasConsumers else {
      easybarLog.debug("aerospace refresh skipped, no registered consumers")
      return
    }

    let generation = currentGeneration()
    easybarLog.debug("aerospace triggerRefresh queued consumers=\(consumers.count)")

    refreshQueue.async { [weak self] in
      guard let self, self.shouldExecute(generation: generation) else { return }
      self.reloadState()
    }
  }

  /// Focuses the requested workspace.
  func focusWorkspace(_ workspace: String) {
    easybarLog.info("aerospace focus workspace requested workspace=\(workspace)")

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      // Update the visible selection immediately for direct clicks in EasyBar.
      self.spaces = self.spaces.map { space in
        SpaceItem(
          id: space.id,
          name: space.name,
          isFocused: space.name == workspace,
          isVisible: space.isVisible,
          apps: space.apps
        )
      }
    }

    refreshQueue.async { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: self.currentGeneration()) else { return }
      _ = self.runAeroSpace(arguments: ["workspace", workspace])
      guard self.shouldExecute(generation: self.currentGeneration()) else { return }
      self.reloadState()
    }
  }

  /// Activates one application shown inside a workspace.
  func focusApp(_ app: SpaceApp) {
    easybarLog.info("aerospace focus app requested app=\(app.name)")

    guard let bundlePath = app.bundlePath, !bundlePath.isEmpty else {
      easybarLog.debug("aerospace focus app skipped, missing bundle path app=\(app.name)")
      return
    }

    DispatchQueue.main.async {
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true

      NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: bundlePath),
        configuration: configuration
      ) { _, error in
        if let error {
          easybarLog.debug("failed to focus app \(app.name): \(error)")
        }
      }
    }
  }

  /// Public refresh entry.
  func refresh() {
    guard hasConsumers else {
      easybarLog.debug("aerospace refresh skipped, no registered consumers")
      return
    }

    let generation = currentGeneration()
    easybarLog.debug("aerospace refresh queued consumers=\(consumers.count)")

    refreshQueue.async { [weak self] in
      guard let self, self.shouldExecute(generation: generation) else { return }
      self.reloadState()
    }
  }
}

// MARK: - App Switch Observation

extension AeroSpaceService {
  /// Listens for app activation so focused-app UI can update immediately.
  fileprivate func subscribeAppSwitches() {
    guard appSwitchObserver == nil else { return }

    appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
      else {
        return
      }

      self.applyOptimisticFocusedApp(from: app)
    }

    easybarLog.debug("aerospace app switch observer installed")
  }

  /// Applies an immediate focused-app update from macOS before AeroSpace catches up.
  fileprivate func applyOptimisticFocusedApp(from app: NSRunningApplication) {
    let bundlePath = app.bundleURL?.path
    let name = app.localizedName ?? ""
    let id = resolvedAppID(name: name, bundlePath: bundlePath)

    guard !id.isEmpty else { return }

    let focused = SpaceApp(
      id: id,
      bundleID: app.bundleIdentifier ?? "",
      name: name,
      bundlePath: bundlePath
    )

    let didChange = focusedApp != focused || focusedAppID != focused.id
    guard didChange else { return }

    focusedApp = focused
    focusedAppID = focused.id

    publishUpdate(logMessage: "aerospace optimistic focus updated app=\(focused.name)")
  }
}

// MARK: - State Reloading

extension AeroSpaceService {
  /// Reads current AeroSpace state and publishes it.
  fileprivate func reloadState() {
    guard shouldExecute(generation: currentGeneration()) else { return }
    easybarLog.debug("aerospace reloadState begin")

    let workspaces = loadWorkspaces()
    let windows = loadWindows()
    let groupedApps = Dictionary(grouping: windows, by: \.workspace)
    let focused = loadFocusedApp()
    let layoutMode = loadFocusedLayoutMode()

    let spaces =
      workspaces
      .map { workspace in
        SpaceItem(
          id: workspace.name,
          name: workspace.name,
          isFocused: workspace.isFocused,
          isVisible: workspace.isVisible,
          apps: deduplicateApps(groupedApps[workspace.name] ?? [])
        )
      }
      .filter { !$0.apps.isEmpty }

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard self.shouldExecute(generation: self.currentGeneration()) else { return }

      let spacesChanged = self.spaces != spaces
      let focusedAppChanged = self.focusedApp != focused
      let focusedAppIDChanged = self.focusedAppID != focused?.id
      let layoutChanged = self.focusedLayoutMode != layoutMode

      guard spacesChanged || focusedAppChanged || focusedAppIDChanged || layoutChanged else {
        easybarLog.debug("aerospace reloadState end without changes")
        return
      }

      self.spaces = spaces
      self.focusedApp = focused
      self.focusedAppID = focused?.id
      self.focusedLayoutMode = layoutMode

      self.publishUpdate(
        logMessage:
          "aerospace state updated spaces=\(spaces.count) focused=\(focused?.name ?? "none") layout=\(layoutMode.rawValue)"
      )

      easybarLog.debug("aerospace reloadState end with changes")
    }
  }
}

// MARK: - AeroSpace Loading

extension AeroSpaceService {
  /// Reads all known workspaces from AeroSpace.
  fileprivate func loadWorkspaces() -> [WorkspaceDTO] {
    guard
      let namesOutput = runAeroSpace(arguments: [
        "list-workspaces", "--all", "--format", "%{workspace}",
      ]),
      let stateOutput = runAeroSpace(arguments: [
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
      .map { String($0) }

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
  fileprivate func loadWindows() -> [WindowDTO] {
    guard
      let output = runAeroSpace(arguments: [
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
  fileprivate func loadFocusedApp() -> SpaceApp? {
    guard
      let output = runAeroSpace(arguments: [
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
    let id = resolvedAppID(name: name, bundlePath: bundlePath)

    if id.isEmpty {
      return nil
    }

    return SpaceApp(
      id: id,
      bundleID: "",
      name: name,
      bundlePath: bundlePath
    )
  }

  /// Reads the currently focused AeroSpace layout mode.
  fileprivate func loadFocusedLayoutMode() -> AeroSpaceLayoutMode {
    guard
      let output = runAeroSpace(arguments: [
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
  fileprivate func deduplicateApps(_ windows: [WindowDTO]) -> [SpaceApp] {
    var seen = Set<String>()
    var result: [SpaceApp] = []

    for window in windows {
      let key = resolvedAppID(
        name: window.name,
        bundlePath: window.bundlePath.isEmpty ? nil : window.bundlePath
      )
      guard !seen.contains(key) else { continue }

      seen.insert(key)
      result.append(makeSpaceApp(name: window.name, bundlePath: window.bundlePath))
    }

    return result
  }

  /// Runs the AeroSpace CLI.
  fileprivate func runAeroSpace(arguments: [String]) -> String? {
    guard isRunning else { return nil }

    guard let executable = resolveAeroSpacePath() else {
      easybarLog.debug("aerospace executable not found")
      return nil
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    let outputHandle = pipe.fileHandleForReading

    do {
      try process.run()
    } catch {
      easybarLog.debug("failed to run aerospace \(arguments.joined(separator: " ")): \(error)")
      return nil
    }

    process.waitUntilExit()
    guard isRunning else {
      try? outputHandle.close()
      return nil
    }

    let data: Data
    do {
      data = try outputHandle.readToEnd() ?? Data()
    } catch {
      easybarLog.debug(
        "failed to read aerospace output args=\(arguments.joined(separator: " ")): \(error)"
      )
      return nil
    }

    if process.terminationStatus != 0 {
      easybarLog.debug(
        "aerospace command exited with status=\(process.terminationStatus) args=\(arguments.joined(separator: " "))"
      )
    }

    return String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Resolves the AeroSpace binary.
  fileprivate func resolveAeroSpacePath() -> String? {
    let candidates = [
      "/opt/homebrew/bin/aerospace",
      "/usr/local/bin/aerospace",
      "/Applications/AeroSpace.app/Contents/MacOS/aerospace",
    ]

    let fm = FileManager.default
    return candidates.first(where: { fm.isExecutableFile(atPath: $0) })
  }

  /// Resolves a stable app identity from bundle path or name.
  fileprivate func resolvedAppID(name: String, bundlePath: String?) -> String {
    guard let bundlePath, !bundlePath.isEmpty else {
      return name
    }

    return bundlePath
  }

  /// Publishes one shared AeroSpace update notification.
  fileprivate func publishUpdate(logMessage: String) {
    easybarLog.debug(logMessage)
    NotificationCenter.default.post(name: .easyBarAeroSpaceDidUpdate, object: nil)
  }

  /// Returns whether the service is still allowed to execute the queued refresh work.
  fileprivate func shouldExecute(generation: UInt64) -> Bool {
    withLock {
      running && self.generation == generation
    }
  }

  /// Returns the current refresh generation.
  fileprivate func currentGeneration() -> UInt64 {
    withLock { generation }
  }

  /// Returns whether the service is currently running.
  fileprivate var isRunning: Bool {
    withLock { running }
  }

  /// Runs one closure while holding the service state lock.
  fileprivate func withLock<T>(_ body: () -> T) -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return body()
  }
}

// MARK: - Parsing

extension AeroSpaceService {
  /// Parses one workspace state line from AeroSpace output.
  fileprivate func parseWorkspaceStateLine(_ line: Substring) -> (String, WorkspaceState)? {
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
  fileprivate func parseWindowLine(_ line: Substring) -> WindowDTO? {
    let parts = splitPipedLine(String(line))
    guard parts.count >= 3 else { return nil }

    return WindowDTO(
      workspace: parts[0],
      name: parts[1],
      bundlePath: parts[2]
    )
  }

  /// Parses one focused layout mode from AeroSpace output.
  fileprivate func parseLayoutMode(_ output: String) -> AeroSpaceLayoutMode {
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
  fileprivate func splitPipedLine(_ line: String) -> [String] {
    line
      .components(separatedBy: " | ")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
  }

  /// Builds one `SpaceApp` from parsed AeroSpace window data.
  fileprivate func makeSpaceApp(name: String, bundlePath: String) -> SpaceApp {
    let normalizedBundlePath = bundlePath.isEmpty ? nil : bundlePath

    return SpaceApp(
      id: resolvedAppID(name: name, bundlePath: normalizedBundlePath),
      bundleID: "",
      name: name,
      bundlePath: normalizedBundlePath
    )
  }
}

extension Notification.Name {
  static let easyBarAeroSpaceDidUpdate = Notification.Name("easybar.aerospace.did-update")
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
