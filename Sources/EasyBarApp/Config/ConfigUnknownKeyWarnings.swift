import Foundation
import TOMLKit

/// Builds warnings for valid TOML keys that EasyBar does not read.
enum ConfigUnknownKeyWarningBuilder {
  /// Returns unknown-key warnings for one parsed config TOML table.
  static func warnings(for table: TOMLTable) -> [String] {
    var warnings: [String] = []
    appendWarnings(in: table, path: "", to: &warnings)
    return warnings
  }

  private static func appendWarnings(
    in table: TOMLTable,
    path: String,
    to warnings: inout [String]
  ) {
    guard !ConfigKnownKeySchema.isFreeFormSection(path) else { return }

    let knownKeys = ConfigKnownKeySchema.knownKeys(for: path)

    for key in table.keys.sorted() {
      guard let value = table[key] else { continue }
      let currentPath = joined(path, key)

      if let nestedTable = value.table {
        guard ConfigKnownKeySchema.isKnownSection(currentPath) else {
          warnings.append("unknown config section \(currentPath)")
          continue
        }

        appendWarnings(in: nestedTable, path: currentPath, to: &warnings)
        continue
      }

      guard knownKeys.contains(key) else {
        warnings.append("unknown config key \(currentPath)")
        continue
      }
    }
  }

  private static func joined(_ path: String, _ key: String) -> String {
    path.isEmpty ? key : "\(path).\(key)"
  }
}
