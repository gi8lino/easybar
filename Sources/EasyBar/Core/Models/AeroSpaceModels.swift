import AppKit
import Foundation

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
