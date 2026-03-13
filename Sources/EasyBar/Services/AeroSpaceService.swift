import Foundation

/// Loads workspace and window state from AeroSpace.
final class AeroSpaceService: ObservableObject {

    @Published private(set) var spaces: [SpaceItem] = []
    @Published private(set) var focusedAppID: String?

    private let refreshQueue = DispatchQueue(label: "easybar.aerospace.refresh", qos: .userInitiated)

    /// Debounce timer used to coalesce bursts of events.
    private var debounceWorkItem: DispatchWorkItem?

    /// Starts the service.
    /// No polling is used anymore — updates arrive through socket events.
    func start() {
        refresh()
    }

    /// Called by the socket server when an external event occurs.
    func triggerRefresh() {
        debounceRefresh()
    }

/// Focuses the requested workspace.
func focusWorkspace(_ workspace: String) {

    // --- Optimistic UI update ---
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }

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

    // --- Tell AeroSpace ---
    refreshQueue.async { [weak self] in
        guard let self else { return }

        _ = self.runAeroSpace(arguments: ["workspace", workspace])

        // Confirm real state
        self.reloadState()

        // One small follow-up refresh
        Thread.sleep(forTimeInterval: 0.04)
        self.reloadState()
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

    /// Reads current AeroSpace state and publishes it.
    private func reloadState() {

        let workspaces = loadWorkspaces()
        let windows = loadWindows()
        let groupedApps = Dictionary(grouping: windows, by: \.workspace)
        let focusedAppID = loadFocusedAppID()

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
            self?.spaces = spaces
            self?.focusedAppID = focusedAppID
        }
    }

    /// Reads all known workspaces from AeroSpace.
    private func loadWorkspaces() -> [WorkspaceDTO] {

        guard
            let namesOutput = runAeroSpace(arguments: ["list-workspaces","--all","--format","%{workspace}"]),
            let stateOutput = runAeroSpace(arguments: ["list-workspaces","--all","--format","%{workspace} %{workspace-is-focused} %{workspace-is-visible}"])
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
        ]) else { return [] }

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

    /// Reads the focused window.
    private func loadFocusedAppID() -> String? {

        guard let output = runAeroSpace(arguments: [
            "list-windows",
            "--focused",
            "--format",
            "%{app-bundle-path} | %{app-name}"
        ]) else { return nil }

        let parts = output
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        if let bundlePath = parts.first, !bundlePath.isEmpty {
            return bundlePath
        }

        if parts.count > 1 {
            return parts[1]
        }

        return nil
    }

    /// Deduplicates apps per workspace.
    private func deduplicateApps(_ windows: [WindowDTO]) -> [SpaceApp] {

        var seen = Set<String>()
        var result: [SpaceApp] = []

        for window in windows {

            let key = window.bundlePath.isEmpty ? window.name : window.bundlePath
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

        try? process.run()
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
