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

    private let refreshQueue = DispatchQueue(label: "easybar.aerospace.refresh", qos: .userInitiated)
    private var debounceWorkItem: DispatchWorkItem?
    private var consumers = Set<String>()
    private var appSwitchObserver: NSObjectProtocol?

    private init() {}

    /// Starts the service.
    func start() {
        subscribeAppSwitches()
        refresh()
    }

    /// Registers one widget that depends on AeroSpace state.
    func registerConsumer(_ id: String) {
        consumers.insert(id)
        Logger.debug("aerospace consumer registered id=\(id) count=\(consumers.count)")
        refresh()
    }

    /// Unregisters one widget that no longer depends on AeroSpace state.
    func unregisterConsumer(_ id: String) {
        consumers.remove(id)
        Logger.debug("aerospace consumer unregistered id=\(id) count=\(consumers.count)")
    }

    /// Returns whether any native widget currently needs AeroSpace state.
    private var hasConsumers: Bool {
        !consumers.isEmpty
    }

    /// Called by the socket server when an external AeroSpace event occurs.
    ///
    /// This path should feel immediate, so it skips the normal debounce and
    /// performs one fast reload plus a short follow-up reload for consistency.
    func triggerRefresh() {
        guard hasConsumers else {
            Logger.debug("aerospace refresh skipped, no registered consumers")
            return
        }

        debounceWorkItem?.cancel()

        refreshQueue.async { [weak self] in
            self?.reloadStateTwice()
        }
    }

    /// Focuses the requested workspace.
    func focusWorkspace(_ workspace: String) {
        Logger.info("aerospace focus workspace requested workspace=\(workspace)")

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

            _ = self.runAeroSpace(arguments: ["workspace", workspace])
            self.reloadStateTwice()
        }
    }

    /// Activates one application shown inside a workspace.
    func focusApp(_ app: SpaceApp) {
        Logger.info("aerospace focus app requested app=\(app.name)")

        guard let bundlePath = app.bundlePath, !bundlePath.isEmpty else {
            Logger.debug("aerospace focus app skipped, missing bundle path app=\(app.name)")
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
                    Logger.debug("failed to focus app \(app.name): \(error)")
                }
            }
        }
    }

    /// Schedules a debounced refresh.
    private func debounceRefresh() {
        debounceWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.refresh()
        }

        debounceWorkItem = work
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.04, execute: work)
    }

    /// Public refresh entry.
    func refresh() {
        refreshQueue.async { [weak self] in
            self?.reloadState()
        }
    }

    /// Listens for app activation so focused-app UI can update immediately.
    private func subscribeAppSwitches() {
        guard appSwitchObserver == nil else { return }

        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else {
                return
            }

            self.applyOptimisticFocusedApp(from: app)
        }
    }

    /// Applies an immediate focused-app update from macOS before AeroSpace catches up.
    private func applyOptimisticFocusedApp(from app: NSRunningApplication) {
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

        focusedApp = focused
        focusedAppID = focused.id

        publishUpdate(logMessage: "aerospace optimistic focus updated app=\(focused.name)")
    }

    /// Reads current AeroSpace state and publishes it.
    private func reloadState() {
        let workspaces = loadWorkspaces()
        let windows = loadWindows()
        let groupedApps = Dictionary(grouping: windows, by: \.workspace)
        let focused = loadFocusedApp()

        let spaces = workspaces
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

            self.spaces = spaces
            self.focusedApp = focused
            self.focusedAppID = focused?.id
            self.publishUpdate(
                logMessage: "aerospace state updated spaces=\(spaces.count) focused=\(focused?.name ?? "none")"
            )
        }
    }

    /// Reloads twice to smooth over small AeroSpace timing gaps.
    private func reloadStateTwice() {
        reloadState()
        Thread.sleep(forTimeInterval: 0.04)
        reloadState()
    }

    /// Reads all known workspaces from AeroSpace.
    private func loadWorkspaces() -> [WorkspaceDTO] {
        guard
            let namesOutput = runAeroSpace(arguments: ["list-workspaces", "--all", "--format", "%{workspace}"]),
            let stateOutput = runAeroSpace(arguments: [
                "list-workspaces",
                "--all",
                "--format",
                "%{workspace} %{workspace-is-focused} %{workspace-is-visible}"
            ])
        else {
            return []
        }

        let names = namesOutput
            .split(whereSeparator: \.isNewline)
            .map { String($0) }

        let stateByWorkspace = Dictionary(uniqueKeysWithValues:
            stateOutput
                .split(whereSeparator: \.isNewline)
                .compactMap { line -> (String, WorkspaceState)? in
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
        )

        return names.map { name in
            let state = stateByWorkspace[name] ?? WorkspaceState(
                isFocused: false,
                isVisible: false
            )

            return WorkspaceDTO(
                name: name,
                isFocused: state.isFocused,
                isVisible: state.isVisible
            )
        }
    }

    /// Reads all windows from AeroSpace.
    private func loadWindows() -> [WindowDTO] {
        guard let output = runAeroSpace(arguments: [
            "list-windows",
            "--all",
            "--format",
            "%{workspace} | %{app-name} | %{app-bundle-path}"
        ]) else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let parts = line
                    .components(separatedBy: " | ")
                    .map { $0.trimmingCharacters(in: .whitespaces) }

                guard parts.count >= 3 else { return nil }

                return WindowDTO(
                    workspace: parts[0],
                    name: parts[1],
                    bundlePath: parts[2]
                )
            }
    }

    /// Reads the currently focused app from AeroSpace.
    private func loadFocusedApp() -> SpaceApp? {
        guard let output = runAeroSpace(arguments: [
            "list-windows",
            "--focused",
            "--format",
            "%{app-bundle-path} | %{app-name}"
        ]) else {
            return nil
        }

        let parts = output
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

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

    /// Deduplicates apps per workspace.
    private func deduplicateApps(_ windows: [WindowDTO]) -> [SpaceApp] {
        var seen = Set<String>()
        var result: [SpaceApp] = []

        for window in windows {
            let key = resolvedAppID(
                name: window.name,
                bundlePath: window.bundlePath.isEmpty ? nil : window.bundlePath
            )
            guard !seen.contains(key) else { continue }

            seen.insert(key)

            result.append(
                SpaceApp(
                    id: key,
                    bundleID: "",
                    name: window.name,
                    bundlePath: window.bundlePath.isEmpty ? nil : window.bundlePath
                )
            )
        }

        return result
    }

    /// Runs the AeroSpace CLI.
    private func runAeroSpace(arguments: [String]) -> String? {
        guard let executable = resolveAeroSpacePath() else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            Logger.debug("failed to run aerospace \(arguments.joined(separator: " ")): \(error)")
            return nil
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolves the AeroSpace binary.
    private func resolveAeroSpacePath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/aerospace",
            "/usr/local/bin/aerospace",
            "/Applications/AeroSpace.app/Contents/MacOS/aerospace"
        ]

        let fm = FileManager.default
        return candidates.first(where: { fm.isExecutableFile(atPath: $0) })
    }

    /// Resolves a stable app identity from bundle path or name.
    private func resolvedAppID(name: String, bundlePath: String?) -> String {
        guard let bundlePath, !bundlePath.isEmpty else {
            return name
        }

        return bundlePath
    }

    /// Publishes one shared AeroSpace update notification.
    private func publishUpdate(logMessage: String) {
        Logger.debug(logMessage)
        NotificationCenter.default.post(name: .easyBarAeroSpaceDidUpdate, object: nil)
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
}

private struct WindowDTO {
    let workspace: String
    let name: String
    let bundlePath: String
}
