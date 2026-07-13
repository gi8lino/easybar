import AppKit
import Foundation

/// A decoded widget image that can safely cross the cache actor boundary.
final class LoadedWidgetImage: @unchecked Sendable {
  let path: String
  let image: NSImage
  let isCustomImage: Bool

  init(path: String, image: NSImage, isCustomImage: Bool) {
    self.path = path
    self.image = image
    self.isCustomImage = isCustomImage
  }
}

/// Decodes and caches path-based widget images away from the main actor.
actor WidgetImageCache {
  static let shared = WidgetImageCache()

  private struct Entry {
    let modificationDate: Date?
    let image: LoadedWidgetImage
  }

  private var entries: [String: Entry] = [:]

  func image(for path: String) -> LoadedWidgetImage {
    let modificationDate = Self.modificationDate(for: path)
    if let entry = entries[path], entry.modificationDate == modificationDate {
      return entry.image
    }

    let customImage = NSImage(contentsOfFile: path)
    let image = customImage ?? NSWorkspace.shared.icon(forFile: path)
    let loaded = LoadedWidgetImage(
      path: path,
      image: image,
      isCustomImage: customImage != nil
    )
    entries[path] = Entry(modificationDate: modificationDate, image: loaded)
    return loaded
  }

  private static func modificationDate(for path: String) -> Date? {
    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    return attributes?[.modificationDate] as? Date
  }
}

/// Publishes cached image loads for one rendered widget node.
@MainActor
final class WidgetImageLoader: ObservableObject {
  @Published private(set) var loadedImage: LoadedWidgetImage?

  func image(for path: String) -> LoadedWidgetImage? {
    guard loadedImage?.path == path else { return nil }
    return loadedImage
  }

  func load(path: String) async {
    let image = await WidgetImageCache.shared.image(for: path)
    guard !Task.isCancelled else { return }
    loadedImage = image
  }
}
