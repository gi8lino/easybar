import AppKit
import Foundation

/// A decoded widget image that can safely cross the cache actor boundary.
final class LoadedWidgetImage: @unchecked Sendable {
  let path: String
  let image: NSImage

  init(path: String, image: NSImage) {
    self.path = path
    self.image = image
  }
}

enum WidgetImageLoadResult: @unchecked Sendable {
  case loaded(LoadedWidgetImage)
  case failed(path: String)
}

/// Decodes and caches path-based widget images away from the main actor.
actor WidgetImageCache {
  static let shared = WidgetImageCache()

  private struct Entry {
    let modificationDate: Date?
    let result: WidgetImageLoadResult
    var lastAccess: UInt64
  }

  private let capacity: Int
  private var entries: [String: Entry] = [:]
  private var accessCounter: UInt64 = 0

  init(capacity: Int = 128) {
    self.capacity = max(1, capacity)
  }

  func image(for path: String) -> WidgetImageLoadResult {
    let modificationDate = Self.modificationDate(for: path)
    accessCounter &+= 1

    if var entry = entries[path], entry.modificationDate == modificationDate {
      entry.lastAccess = accessCounter
      entries[path] = entry
      return entry.result
    }

    let result =
      NSImage(contentsOfFile: path).map {
        WidgetImageLoadResult.loaded(LoadedWidgetImage(path: path, image: $0))
      } ?? .failed(path: path)
    entries[path] = Entry(
      modificationDate: modificationDate,
      result: result,
      lastAccess: accessCounter
    )
    evictLeastRecentlyUsedEntryIfNeeded()
    return result
  }

  private func evictLeastRecentlyUsedEntryIfNeeded() {
    guard entries.count > capacity else { return }
    guard let oldestPath = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else {
      return
    }
    entries.removeValue(forKey: oldestPath)
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
  private var loggedFailurePaths = Set<String>()

  func image(for path: String) -> LoadedWidgetImage? {
    guard loadedImage?.path == path else { return nil }
    return loadedImage
  }

  func load(path: String) async -> Bool {
    let result = await WidgetImageCache.shared.image(for: path)
    guard !Task.isCancelled else { return false }

    switch result {
    case .loaded(let image):
      loadedImage = image
      loggedFailurePaths.remove(path)
      return false
    case .failed:
      if loadedImage?.path == path {
        loadedImage = nil
      }
      return loggedFailurePaths.insert(path).inserted
    }
  }
}
