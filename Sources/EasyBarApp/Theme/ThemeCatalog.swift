import Foundation

/// Discovers bundled and user-provided themes available for session preview.
enum ThemeCatalog {
  /// Returns normalized theme names in stable display order.
  static func availableThemeNames(for snapshot: ConfigSnapshot) -> [String] {
    var directories: [URL] = []

    let userDirectory = NSString(string: snapshot.theme.themesDir).expandingTildeInPath
    if !userDirectory.isEmpty {
      directories.append(URL(fileURLWithPath: userDirectory, isDirectory: true))
    }
    if let resourceURL = Bundle.main.resourceURL {
      directories.append(resourceURL.appendingPathComponent("Themes", isDirectory: true))
    }
    if let executableURL = Bundle.main.executableURL {
      directories.append(
        executableURL.deletingLastPathComponent()
          .deletingLastPathComponent()
          .appendingPathComponent("Resources/Themes", isDirectory: true)
      )
    }
    directories.append(
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("themes", isDirectory: true)
    )

    var names: Set<String> = [snapshot.theme.configuredName, snapshot.theme.name]
    for directory in directories {
      guard
        let urls = try? FileManager.default.contentsOfDirectory(
          at: directory,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
      else { continue }

      for url in urls where url.pathExtension.lowercased() == "toml" {
        names.insert(url.deletingPathExtension().lastPathComponent.lowercased())
      }
    }

    return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }
}
