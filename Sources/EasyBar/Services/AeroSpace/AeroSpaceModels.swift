import AppKit
import Foundation

/// The current AeroSpace layout mode resolved from the focused window/container.
enum AeroSpaceLayoutMode: String, Codable {
  case hTiles = "h_tiles"
  case vTiles = "v_tiles"
  case hAccordion = "h_accordion"
  case vAccordion = "v_accordion"
  case floating
  case unknown
}

/// A single running application shown inside a workspace.
struct SpaceApp: Identifiable, Hashable {
  let id: String
  let bundleID: String
  let name: String
  let bundlePath: String?

  /// Returns the application icon if the bundle path is known.
  func icon() -> NSImage? {
    guard let bundlePath, !bundlePath.isEmpty else { return nil }
    return NSWorkspace.shared.icon(forFile: bundlePath)
  }
}

/// A workspace shown in the bar.
struct SpaceItem: Identifiable, Hashable {
  let id: String
  let name: String
  let isFocused: Bool
  let isVisible: Bool
  let apps: [SpaceApp]
}
