import EasyBarConfigParsing
import EasyBarShared
import Foundation

/// Applies validated, comment-preserving edits to the active configuration file.
@MainActor
final class ConfigPersistence {
  private let configPath: String
  private let logger: ProcessLogger

  init(configPath: String, logger: ProcessLogger) {
    self.configPath = configPath
    self.logger = logger
  }

  /// Writes one batch atomically after parsing both the input and edited document.
  func apply(_ edits: [TOMLEdit]) -> Bool {
    guard !edits.isEmpty else { return true }
    let url = URL(fileURLWithPath: configPath)

    do {
      let source: String
      if FileManager.default.fileExists(atPath: url.path) {
        source = try String(contentsOf: url, encoding: .utf8)
      } else {
        source = ""
      }

      _ = try TOMLTable(string: source)
      let edited = try TOMLDocument.edit(source, edits: edits)
      _ = try TOMLTable(string: edited)
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try edited.write(to: url, atomically: true, encoding: .utf8)
      logger.info(
        "persisted config changes",
        .field("path", configPath),
        .field("count", edits.count)
      )
      return true
    } catch {
      logger.error(
        "failed to persist config changes",
        .field("path", configPath),
        .field("error", error.localizedDescription)
      )
      return false
    }
  }
}
