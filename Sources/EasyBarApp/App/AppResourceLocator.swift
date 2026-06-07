import Foundation

/// Resolves EasyBar app resources without relying on SwiftPM's generated Bundle.module accessor.
///
/// Release bundles stage SwiftPM resources inside Contents/Resources so the app can be signed
/// with the standard macOS bundle layout. SwiftPM's generated accessor only checks the app-bundle
/// root, so packaged builds must use explicit candidate paths instead.
enum AppResourceLocator {
  /// Name of the SwiftPM resource bundle produced for the app target.
  private static let resourceBundleName = "EasyBar_EasyBarApp.bundle"

  /// Returns one bundled resource URL from packaged, build, or source-tree locations.
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
    var candidates: [URL] = []
    let fileName = "\(name).\(fileExtension)"

    for root in resourceBundleRoots() {
      candidates.append(
        root
          .appendingOptionalSubdirectory(subdirectory)
          .appendingPathComponent(fileName)
      )
    }

    for sourceRoot in sourceRoots() {
      candidates.append(
        sourceRoot
          .appendingOptionalSubdirectory(subdirectory)
          .appendingPathComponent(fileName)
      )

      candidates.append(
        sourceRoot
          .appendingPathComponent("Lua", isDirectory: true)
          .appendingPathComponent(fileName)
      )
    }

    return unique(candidates)
  }

  /// Returns resource-bundle roots for packaged apps, legacy packages, and SwiftPM builds.
  private static func resourceBundleRoots() -> [URL] {
    var roots: [URL] = []

    if let resourceURL = Bundle.main.resourceURL {
      roots.append(
        resourceURL.appendingPathComponent(resourceBundleName, isDirectory: true)
      )
    }

    roots.append(
      Bundle.main.bundleURL.appendingPathComponent(resourceBundleName, isDirectory: true)
    )

    if let executableURL = Bundle.main.executableURL {
      let executableDirectory = executableURL.deletingLastPathComponent()

      roots.append(
        executableDirectory
          .deletingLastPathComponent()
          .appendingPathComponent("Resources", isDirectory: true)
          .appendingPathComponent(resourceBundleName, isDirectory: true)
      )

      roots.append(
        executableDirectory.appendingPathComponent(resourceBundleName, isDirectory: true)
      )
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
  /// Appends one optional subdirectory when present.
  fileprivate func appendingOptionalSubdirectory(_ subdirectory: String?) -> URL {
    guard let subdirectory, !subdirectory.isEmpty else { return self }

    return appendingPathComponent(subdirectory, isDirectory: true)
  }
}
