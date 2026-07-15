import EasyBarConfigSchema
import Foundation
import XCTest

final class ConfigReferenceTests: ConfigLoaderTestCase {
  func testGeneratedReferenceContainsEveryDocumentedSchemaKey() throws {
    let referenceURL = repoRootURL()
      .appendingPathComponent("docs/content/configuration/reference.md")
    let reference = try String(contentsOf: referenceURL, encoding: .utf8)

    XCTAssertEqual(referenceKeys(in: reference), documentedSchemaKeys())
  }

  private func documentedSchemaKeys() -> Set<String> {
    var keys: Set<String> = []
    var currentSection: String?
    var currentSectionIsDocumented = false

    for line in ConfigSchemaRegistry.lines {
      switch line {
      case .section(let name, _, _, let documented):
        currentSection = name
        currentSectionIsDocumented = documented

      case .entry(let key, _, _, _, _, let documented):
        guard let currentSection, currentSectionIsDocumented, documented else { continue }
        keys.insert("\(currentSection).\(key)")

      case .optionalEntry(let key, _, _):
        guard let currentSection, currentSectionIsDocumented else { continue }
        keys.insert("\(currentSection).\(key)")

      case .blank, .comment:
        continue
      }
    }

    return keys
  }

  private func referenceKeys(in reference: String) -> Set<String> {
    var keys: Set<String> = []
    var currentSection: String?

    for line in reference.split(separator: "\n", omittingEmptySubsequences: false) {
      let value = String(line)

      if value.hasPrefix("## `"), value.hasSuffix("`") {
        currentSection = String(value.dropFirst(4).dropLast())
        continue
      }

      guard value.hasPrefix("| `"), let currentSection else { continue }
      let columns = value.split(separator: "|", omittingEmptySubsequences: true)
      guard let firstColumn = columns.first else { continue }
      let rawKey = String(firstColumn).trimmingCharacters(in: .whitespaces)
      guard
        rawKey.hasPrefix("`"), rawKey.hasSuffix("`")
      else {
        continue
      }

      keys.insert("\(currentSection).\(rawKey.dropFirst().dropLast())")
    }

    return keys
  }
}
