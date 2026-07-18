import Foundation

struct InboxPersistedState: Codable, Equatable {
  var readItemIDs: Set<String> = []
  var unreadItemIDs: Set<String> = []
  var dismissedItemIDs: Set<String> = []
}

struct InboxStatePersistence {
  let fileURL: URL

  func load() -> InboxPersistedState {
    guard let data = try? Data(contentsOf: fileURL) else { return .init() }
    return (try? JSONDecoder().decode(InboxPersistedState.self, from: data)) ?? .init()
  }

  func save(_ state: InboxPersistedState) {
    guard let data = try? JSONEncoder().encode(state) else { return }
    let directory = fileURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? data.write(to: fileURL, options: .atomic)
  }
}
