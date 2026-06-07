import Foundation

/// Resolves EasyBar app resources without relying on SwiftPM's generated Bundle.module accessor.
///
/// Packaged app bundles stage resources under `Contents/Resources/EasyBar`:
///
/// - `Lua/runtime.lua`
/// - `Lua/easybar_api.lua`
/// - `Lua/easybar/...`
/// - `Events/event_catalog.json`
/// - `ThemeTokens/theme_tokens.json`
///
/// Source-tree and SwiftPM resource-bundle fallbacks are kept so tests and local development
/// continue to work before resources are staged into an app bundle.
enum AppResourceLocator {
  /// Name of the app-owned resource directory inside `Contents/Resources`.
  private static let appResourceDirectoryName = "EasyBar"
  /// Name of the SwiftPM resource bundle produced for the app target.
  private static let legacyResourceBundleName = "EasyBar_EasyBarApp.bundle"

  /// Returns one bundled resource URL from packaged, SwiftPM build, or source-tree locations.
  static func url(
    forResource name: String,
    withExtension fileExtension: String,
    subdirectory: String? = nil
  ) -> URL? {
    let fileManager = FileManager.default

    for candidate in resourceCandidates(
      forResource: name,
      withExtension: fileExtension,
      subdirectory: subdirectory
    ) {
      if fileManager.fileExists(atPath: candidate.path) {
        return candidate
      }
    }

    return nil
  }

  /// Returns candidate URLs for one resource in the order they should be preferred.
  private static func resourceCandidates(
    forResource name: String,
    withExtension fileExtension: String,
    subdirectory: String?
  ) -> [URL] {
    let fileName = "\(name).\(fileExtension)"
    var candidates: [URL] = []

    for root in packagedResourceRoots() {
      candidates.append(
        root
          .appendingOptionalSubdirectory(
            packagedSubdirectory(forResource: name, withExtension: fileExtension, subdirectory: subdirectory)
          )
          .appendingPathComponent(fileName)
      )
    }

    for root in legacyResourceBundleRoots() {
      candidates.append(
        root
          .appendingOptionalSubdirectory(subdirectory)
          .appendingPathComponent(fileName)
      )

      // SwiftPM `.copy` resources are placed at the resource-bundle root. Keep this fallback for
      // build products and older staged bundles where callers may request a logical subdirectory.
      candidates.append(root.appendingPathComponent(fileName))
    }

    for root in sourceRoots() {
      candidates.append(
        root
          .appendingOptionalSubdirectory(
            sourceSubdirectory(forResource: name, withExtension: fileExtension, subdirectory: subdirectory)
          )
          .appendingPathComponent(fileName)
      )
    }

    return unique(candidates)
  }

  /// Returns packaged app resource roots.
  private static func packagedResourceRoots() -> [URL] {
    var roots: [URL] = []

    if let resourceURL = Bundle.main.resourceURL {
      roots.append(resourceURL.appendingPathComponent(appResourceDirectoryName, isDirectory: true))
    }

    if let executableURL = Bundle.main.executableURL {
      roots.append(
        executableURL
          .deletingLastPathComponent()
          .deletingLastPathComponent()
          .appendingPathComponent("Resources", isDirectory: true)
          .appendingPathComponent(appResourceDirectoryName, isDirectory: true)
      )
    }

    return unique(roots)
  }

  /// Returns legacy SwiftPM resource-bundle roots for tests, build outputs, and old packages.
  private static func legacyResourceBundleRoots() -> [URL] {
    var roots: [URL] = []

    if let resourceURL = Bundle.main.resourceURL {
      roots.append(resourceURL.appendingPathComponent(legacyResourceBundleName, isDirectory: true))
    }

    roots.append(Bundle.main.bundleURL.appendingPathComponent(legacyResourceBundleName, isDirectory: true))

    if let executableURL = Bundle.main.executableURL {
      let executableDirectory = executableURL.deletingLastPathComponent()

      roots.append(
        executableDirectory
          .deletingLastPathComponent()
          .appendingPathComponent("Resources", isDirectory: true)
          .appendingPathComponent(legacyResourceBundleName, isDirectory: true)
      )

      roots.append(executableDirectory.appendingPathComponent(legacyResourceBundleName, isDirectory: true))
    }

    return unique(roots)
  }

  /// Returns source-tree roots used by tests and direct local development runs.
  private static func sourceRoots() -> [URL] {
    let fileURL = URL(fileURLWithPath: #filePath)
    let sourceRoot =
      fileURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    return unique([
      sourceRoot,
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("EasyBarApp", isDirectory: true),
    ])
  }

  /// Maps logical resource requests to the packaged app resource layout.
  private static func packagedSubdirectory(
    forResource name: String,
    withExtension fileExtension: String,
    subdirectory: String?
  ) -> String? {
    if let subdirectory, !subdirectory.isEmpty {
      switch subdirectory {
      case "Events":
        return "Events"
      case "Theme", "ThemeTokens":
        return "ThemeTokens"
      case "Lua":
        return "Lua"
      default:
        return subdirectory.hasPrefix("Lua/") ? subdirectory : "Lua/\(subdirectory)"
      }
    }

    if fileExtension == "lua" {
      return "Lua"
    }

    switch name {
    case "event_catalog":
      return "Events"
    case "theme_tokens":
      return "ThemeTokens"
    default:
      return nil
    }
  }

  /// Maps logical resource requests to the source-tree layout.
  private static func sourceSubdirectory(
    forResource name: String,
    withExtension fileExtension: String,
    subdirectory: String?
  ) -> String? {
    if let subdirectory, !subdirectory.isEmpty {
      switch subdirectory {
      case "ThemeTokens":
        return "Theme"
      default:
        return subdirectory
      }
    }

    if fileExtension == "lua" {
      return "Lua"
    }

    switch name {
    case "event_catalog":
      return "Events"
    case "theme_tokens":
      return "Theme"
    default:
      return nil
    }
  }

  /// Returns URLs without duplicate standardized paths.
  private static func unique(_ urls: [URL]) -> [URL] {
    var seen: Set<String> = []
    var result: [URL] = []

    for url in urls {
      let path = url.standardizedFileURL.path
      guard !seen.contains(path) else { continue }
      seen.insert(path)
      result.append(url)
    }

    return result
  }
}

extension URL {
  /// Appends one slash-separated optional subdirectory when present.
  fileprivate func appendingOptionalSubdirectory(_ subdirectory: String?) -> URL {
    guard let subdirectory, !subdirectory.isEmpty else { return self }

    var result = self
    for component in subdirectory.split(separator: "/") {
      result = result.appendingPathComponent(String(component), isDirectory: true)
    }
    return result
  }
}
