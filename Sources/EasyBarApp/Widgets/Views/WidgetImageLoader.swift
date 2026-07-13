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

struct WidgetImageRevision: Hashable, Sendable {
  let path: String
  let modificationDate: Date?
  let fileSize: UInt64?

  init(path: String) {
    self.path = path
    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    self.modificationDate = attributes?[.modificationDate] as? Date
    self.fileSize = (attributes?[.size] as? NSNumber)?.uint64Value
  }
}

/// Decodes and caches path-based widget images away from the main actor.
actor WidgetImageCache {
  static let shared = WidgetImageCache()

  private struct Entry {
    let revision: WidgetImageRevision
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
    image(for: WidgetImageRevision(path: path))
  }

  func image(for revision: WidgetImageRevision) -> WidgetImageLoadResult {
    accessCounter &+= 1

    if var entry = entries[revision.path], entry.revision == revision {
      entry.lastAccess = accessCounter
      entries[revision.path] = entry
      return entry.result
    }

    let result =
      NSImage(contentsOfFile: revision.path).map {
        WidgetImageLoadResult.loaded(LoadedWidgetImage(path: revision.path, image: $0))
      } ?? .failed(path: revision.path)
    entries[revision.path] = Entry(
      revision: revision,
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
    await load(revision: WidgetImageRevision(path: path))
  }

  func load(revision: WidgetImageRevision) async -> Bool {
    let result = await WidgetImageCache.shared.image(for: revision)
    guard !Task.isCancelled else { return false }

    switch result {
    case .loaded(let image):
      loadedImage = image
      loggedFailurePaths.remove(revision.path)
      return false
    case .failed:
      if loadedImage?.path == revision.path {
        loadedImage = nil
      }
      return loggedFailurePaths.insert(revision.path).inserted
    }
  }
}
