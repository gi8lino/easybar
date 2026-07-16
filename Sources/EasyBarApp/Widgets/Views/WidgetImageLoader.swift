import AppKit
import Foundation

/// One validated source for a rendered widget image.
enum WidgetImageSource: Hashable, Sendable {
  static let maximumInlineSVGBytes = 256 * 1024

  case path(String)
  case svg(String)

  var diagnosticLabel: String {
    switch self {
    case .path(let path): return path
    case .svg: return "inline-svg"
    }
  }
}

/// A decoded widget image that can safely cross the cache actor boundary.
final class LoadedWidgetImage: @unchecked Sendable {
  let source: WidgetImageSource
  let image: NSImage

  init(source: WidgetImageSource, image: NSImage) {
    self.source = source
    self.image = image
  }
}

enum WidgetImageLoadResult: @unchecked Sendable {
  case loaded(LoadedWidgetImage)
  case failed(source: WidgetImageSource)
}

struct WidgetImageRevision: Hashable, Sendable {
  let source: WidgetImageSource
  let modificationDate: Date?
  let fileSize: UInt64?

  init(path: String) {
    self.init(source: .path(path))
  }

  init(source: WidgetImageSource) {
    self.source = source

    switch source {
    case .path(let path):
      let attributes = try? FileManager.default.attributesOfItem(atPath: path)
      self.modificationDate = attributes?[.modificationDate] as? Date
      self.fileSize = (attributes?[.size] as? NSNumber)?.uint64Value
    case .svg:
      self.modificationDate = nil
      self.fileSize = nil
    }
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
  private var entries: [WidgetImageSource: Entry] = [:]
  private var accessCounter: UInt64 = 0

  init(capacity: Int = 128) {
    self.capacity = max(1, capacity)
  }

  func image(for path: String) -> WidgetImageLoadResult {
    image(for: .path(path))
  }

  func image(for source: WidgetImageSource) -> WidgetImageLoadResult {
    image(for: WidgetImageRevision(source: source))
  }

  func image(for revision: WidgetImageRevision) -> WidgetImageLoadResult {
    accessCounter &+= 1

    if var entry = entries[revision.source], entry.revision == revision {
      entry.lastAccess = accessCounter
      entries[revision.source] = entry
      return entry.result
    }

    let image: NSImage?
    switch revision.source {
    case .path(let path):
      image = NSImage(contentsOfFile: path)
    case .svg(let svg):
      image = NSImage(data: Data(svg.utf8))
    }

    let result =
      image.map {
        WidgetImageLoadResult.loaded(LoadedWidgetImage(source: revision.source, image: $0))
      } ?? .failed(source: revision.source)
    entries[revision.source] = Entry(
      revision: revision,
      result: result,
      lastAccess: accessCounter
    )
    evictLeastRecentlyUsedEntryIfNeeded()
    return result
  }

  private func evictLeastRecentlyUsedEntryIfNeeded() {
    guard entries.count > capacity else { return }
    guard let oldestSource = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else {
      return
    }
    entries.removeValue(forKey: oldestSource)
  }

}

/// Publishes cached image loads for one rendered widget node.
@MainActor
final class WidgetImageLoader: ObservableObject {
  @Published private(set) var loadedImage: LoadedWidgetImage?
  private var loggedFailures = Set<WidgetImageSource>()

  func image(for path: String) -> LoadedWidgetImage? {
    image(for: .path(path))
  }

  func image(for source: WidgetImageSource) -> LoadedWidgetImage? {
    guard loadedImage?.source == source else { return nil }
    return loadedImage
  }

  func load(path: String) async -> Bool {
    await load(source: .path(path))
  }

  func load(source: WidgetImageSource) async -> Bool {
    await load(revision: WidgetImageRevision(source: source))
  }

  func load(revision: WidgetImageRevision) async -> Bool {
    let result = await WidgetImageCache.shared.image(for: revision)
    guard !Task.isCancelled else { return false }

    switch result {
    case .loaded(let image):
      loadedImage = image
      loggedFailures.remove(revision.source)
      return false
    case .failed:
      if loadedImage?.source == revision.source {
        loadedImage = nil
      }
      return loggedFailures.insert(revision.source).inserted
    }
  }
}
