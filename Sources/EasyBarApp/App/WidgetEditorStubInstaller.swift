import CryptoKit
import EasyBarShared
import Foundation

/// Installs the bundled Lua editor stub into the configured editor-stub path.
struct WidgetEditorStubInstaller {
  private let logger: ProcessLogger

  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Installs the bundled Lua editor stub when the configured file is missing or stale.
  func install(stubPath: String) {
    guard let bundledStub = AppResourceLocator.url(forResource: "easybar_api", withExtension: "lua")
    else {
      logger.warn("easybar_api.lua not found in bundle resources")
      return
    }

    let installedStub = URL(fileURLWithPath: stubPath)

    do {
      let bundledData = try Data(contentsOf: bundledStub)
      let existingData = try? Data(contentsOf: installedStub)
      let bundledHash = sha256Hex(for: bundledData)
      let existingHash = existingData.map(sha256Hex)

      guard bundledHash != existingHash else {
        return
      }

      try FileManager.default.createDirectory(
        at: installedStub.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try bundledData.write(to: installedStub, options: .atomic)

      logger.info(
        "installed widget editor stub",
        .field("bundled_hash", bundledHash),
        .field("previous_hash", existingHash ?? "<missing>"),
        .field("path", installedStub.path)
      )
    } catch {
      logger.warn("failed to install widget editor stub", .field("error", error))
    }
  }

  /// Returns the SHA-256 digest for one Lua editor stub payload.
  private func sha256Hex(for data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
