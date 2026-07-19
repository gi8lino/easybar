import Foundation

struct InboxPersistedState: Codable, Equatable {
  var readItemIDs: Set<String> = []
  var unreadItemIDs: Set<String> = []
  var dismissedItemIDs: Set<String> = []

  private enum CodingKeys: String, CodingKey {
    case readItemIDs
    case unreadItemIDs
    case dismissedItemIDs
  }

  init(
    readItemIDs: Set<String> = [],
    unreadItemIDs: Set<String> = [],
    dismissedItemIDs: Set<String> = []
  ) {
    self.readItemIDs = readItemIDs
    self.unreadItemIDs = unreadItemIDs
    self.dismissedItemIDs = dismissedItemIDs
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    readItemIDs = Set(try container.decodeIfPresent([String].self, forKey: .readItemIDs) ?? [])
    unreadItemIDs = Set(try container.decodeIfPresent([String].self, forKey: .unreadItemIDs) ?? [])
    dismissedItemIDs = Set(
      try container.decodeIfPresent([String].self, forKey: .dismissedItemIDs) ?? [])
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(readItemIDs.sorted(), forKey: .readItemIDs)
    try container.encode(unreadItemIDs.sorted(), forKey: .unreadItemIDs)
    try container.encode(dismissedItemIDs.sorted(), forKey: .dismissedItemIDs)
  }
}

struct InboxStatePersistence {
  let fileURL: URL

  func load() -> InboxPersistedState {
    guard let data = try? Data(contentsOf: fileURL) else { return .init() }
    return (try? JSONDecoder().decode(InboxPersistedState.self, from: data)) ?? .init()
  }

  func save(_ state: InboxPersistedState) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard var data = try? encoder.encode(state) else { return }
    data.append(0x0A)
    let directory = fileURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? data.write(to: fileURL, options: .atomic)
  }
}
