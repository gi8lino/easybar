import Foundation

extension Config {

  /// One resolved filesystem requirement for the runtime.
  struct RequiredDirectory {
    enum Kind {
      case directory
      case parentDirectory
    }

    let configPath: String
    let path: String
    let kind: Kind
  }

  /// Removes all currently registered directory requirements.
  func resetRegisteredDirectories() {
    registeredDirectories.removeAll()
  }

  /// Registers or replaces one required runtime directory.
  ///
  /// The registry is keyed by config path so later values for the same config
  /// field replace earlier ones cleanly within the same load cycle.
  func registerDirectoryRequirement(
    for configPath: String,
    path: String,
    kind: RequiredDirectory.Kind
  ) {
    registeredDirectories[configPath] = RequiredDirectory(
      configPath: configPath,
      path: path,
      kind: kind
    )
  }

  /// Ensures all registered runtime-required directories exist.
  func ensureRequiredDirectoriesExist() throws {
    for requiredDirectory in registeredDirectories.values.sorted(by: {
      $0.configPath < $1.configPath
    }) {
      switch requiredDirectory.kind {
      case .directory:
        try ensureDirectoryExists(
          at: requiredDirectory.path,
          path: requiredDirectory.configPath
        )

      case .parentDirectory:
        try ensureParentDirectoryExists(
          forFileAt: requiredDirectory.path,
          path: requiredDirectory.configPath
        )
      }
    }
  }

  /// Creates one configured directory when it does not already exist.
  private func ensureDirectoryExists(
    at pathValue: String,
    path: String
  ) throws {
    let trimmedPath = pathValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPath.isEmpty else { return }

    let expandedPath = NSString(string: trimmedPath).expandingTildeInPath
    let url = URL(fileURLWithPath: expandedPath, isDirectory: true)

    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
      atPath: url.path,
      isDirectory: &isDirectory
    )

    if exists {
      guard isDirectory.boolValue else {
        throw ConfigError.invalidValue(
          path: path,
          message: "expected directory path, but found file at \(url.path)"
        )
      }
      return
    }

    do {
      try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true
      )
      easybarLog.info("created directory path=\(url.path)")
    } catch {
      throw ConfigError.invalidValue(
        path: path,
        message: "failed to create directory at \(url.path): \(error)"
      )
    }
  }

  /// Creates the parent directory for one configured file path when needed.
  private func ensureParentDirectoryExists(
    forFileAt pathValue: String,
    path: String
  ) throws {
    let trimmedPath = pathValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPath.isEmpty else { return }

    let expandedPath = NSString(string: trimmedPath).expandingTildeInPath
    let fileURL = URL(fileURLWithPath: expandedPath)
    let parentURL = fileURL.deletingLastPathComponent()

    try ensureDirectoryExists(
      at: parentURL.path,
      path: path
    )
  }
}
