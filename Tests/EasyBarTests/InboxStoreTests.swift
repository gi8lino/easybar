import EasyBarShared
import XCTest

@testable import EasyBarApp

@MainActor
final class InboxStoreTests: XCTestCase {
  func testReplacementTracksUnreadStateAndRemovesStaleItems() {
    let store = InboxStore()
    store.replace(source: "GitLab", items: [item("one", timestamp: 1), item("two", timestamp: 2)])

    XCTAssertEqual(store.presentedItems.map(\.item.id), ["two", "one"])
    XCTAssertEqual(store.unreadCount, 2)

    store.markRead(store.presentedItems[0])
    XCTAssertEqual(store.unreadCount, 1)

    store.replace(source: "GitLab", items: [item("two", timestamp: 3)])
    XCTAssertEqual(store.presentedItems.map(\.item.id), ["two"])
    XCTAssertEqual(store.unreadCount, 0)
  }

  func testReplacementLimitCountsUniqueItemIDs() {
    var config = Config.InboxBuiltinConfig.default
    config.maxItems = 2
    let store = InboxStore(configuration: config)

    store.replace(
      source: "GitHub",
      items: [
        item("one", title: "Older"),
        item("one", title: "Newer"),
        item("two", title: "Second"),
        item("three", title: "Over limit"),
      ]
    )

    XCTAssertEqual(Set(store.presentedItems.map(\.item.id)), ["one", "two"])
    XCTAssertEqual(store.presentedItems.first { $0.item.id == "one" }?.item.title, "Newer")
  }

  func testGroupingUsesConfiguredCategoryAndFallback() {
    var config = Config.InboxBuiltinConfig.default
    config.groupBy = .category
    let store = InboxStore(configuration: config)
    store.replace(
      source: "GitLab",
      items: [item("one", category: "Reviews"), item("two", category: nil)]
    )

    XCTAssertEqual(store.groups().map(\.title), ["Reviews", "Other"])
  }

  func testClearAllRemovesMessagesAndReadState() {
    let store = InboxStore()
    store.replace(source: "GitHub", items: [item("one")])
    store.markAllRead()
    store.clearAll()
    store.replace(source: "GitHub", items: [item("one")])

    XCTAssertEqual(store.unreadCount, 1)
  }

  func testReadStateCanBeToggledAndPersistsAcrossReplacement() {
    let store = InboxStore()
    store.replace(source: "GitHub", items: [item("one")])
    let original = store.presentedItems[0]

    store.toggleRead(original)
    XCTAssertEqual(store.unreadCount, 0)

    store.toggleRead(store.presentedItems[0])
    XCTAssertEqual(store.unreadCount, 1)

    store.replace(source: "GitHub", items: [item("one")])
    XCTAssertEqual(store.unreadCount, 1)
  }

  func testInitiallyReadItemCanBeMarkedUnread() {
    let store = InboxStore()
    var readItem = item("one")
    readItem = InboxItem(
      id: readItem.id,
      title: readItem.title,
      body: readItem.body,
      format: readItem.format,
      timestamp: readItem.timestamp,
      category: readItem.category,
      severity: readItem.severity,
      unread: false,
      dismissible: readItem.dismissible,
      actions: readItem.actions
    )
    store.replace(source: "GitHub", items: [readItem])

    store.markUnread(store.presentedItems[0])

    XCTAssertEqual(store.unreadCount, 1)
  }

  func testDismissSuppressesItemUntilPublisherRemovesIt() {
    let store = InboxStore()
    store.replace(source: "GitHub", items: [item("one")])
    store.dismiss(store.presentedItems[0])
    XCTAssertTrue(store.presentedItems.isEmpty)

    store.replace(source: "GitHub", items: [item("one")])
    XCTAssertTrue(store.presentedItems.isEmpty)

    store.replace(source: "GitHub", items: [])
    store.replace(source: "GitHub", items: [item("one")])
    XCTAssertEqual(store.presentedItems.map(\.item.id), ["one"])
  }

  func testDismissAllKeepsNonDismissibleControls() {
    let store = InboxStore()
    store.replace(
      source: "Homebrew",
      items: [item("package"), item("controls", dismissible: false)]
    )

    store.dismissAll()

    XCTAssertEqual(store.presentedItems.map(\.item.id), ["controls"])
  }

  func testLocalStatePersistsWithoutMessageContentAndReconcilesPerSource() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateURL = directory.appendingPathComponent("inbox-state.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = InboxStore(stateURL: stateURL)
    first.replace(source: "GitHub", items: [item("gh-1", title: "github-secret-title")])
    first.markRead(first.presentedItems[0])
    first.replace(source: "GitLab", items: [item("gl-1", title: "gitlab-secret-title")])
    first.dismiss(first.presentedItems.first { $0.source == "GitLab" }!)

    let persistedText = try String(contentsOf: stateURL, encoding: .utf8)
    XCTAssertFalse(persistedText.contains("secret-title"))

    let restored = InboxStore(stateURL: stateURL)
    restored.replace(source: "GitHub", items: [item("gh-1", title: "github-secret-title")])
    XCTAssertEqual(restored.unreadCount, 0)
    restored.replace(source: "GitLab", items: [item("gl-1", title: "gitlab-secret-title")])
    XCTAssertEqual(restored.presentedItems.map(\.source), ["GitHub"])
  }

  func testInvalidItemsAreDropped() {
    let store = InboxStore()
    store.replace(source: "GitLab", items: [item(""), item("valid")])

    XCTAssertEqual(store.presentedItems.map(\.item.id), ["valid"])
  }

  func testCompositeIDSeparatorIsRejectedInSourcesAndItemIDs() {
    let store = InboxStore()
    store.replace(source: "GitHub\u{1f}shared", items: [item("one")])
    store.replace(source: "GitHub", items: [item("shared\u{1f}one"), item("valid")])

    XCTAssertEqual(store.presentedItems.map(\.item.id), ["valid"])
    XCTAssertEqual(store.presentedItems.map(\.source), ["GitHub"])
  }

  func testSourceActionsRemainConfiguredWhenMessagesAreCleared() {
    let store = InboxStore()
    store.configure(
      source: "GitLab",
      actions: [InboxAction(id: "refresh", title: "Refresh")]
    )

    XCTAssertEqual(
      store.sourceConfigurations,
      [
        InboxSourceConfiguration(
          source: "GitLab",
          actions: [InboxAction(id: "refresh", title: "Refresh")]
        )
      ]
    )

    store.clear(source: "GitLab")
    XCTAssertEqual(store.sourceConfigurations.first?.source, "GitLab")

    store.configure(source: "GitLab", actions: [])
    XCTAssertTrue(store.sourceConfigurations.isEmpty)
  }

  func testSourceIsNormalizedConsistently() {
    let store = InboxStore()
    store.replace(source: "  GitLab\n", items: [item("one")])
    store.configure(
      source: "\tGitLab ",
      actions: [InboxAction(id: "refresh", title: "Refresh")]
    )

    XCTAssertEqual(store.presentedItems.map(\.source), ["GitLab"])
    XCTAssertEqual(store.sourceConfigurations.map(\.source), ["GitLab"])

    store.clear(source: " GitLab ")

    XCTAssertTrue(store.presentedItems.isEmpty)
  }

  func testInvalidSourceContextActionsAreDropped() {
    let store = InboxStore()
    store.configure(
      source: "GitLab",
      actions: [InboxAction(id: "", title: "Refresh")]
    )

    XCTAssertTrue(store.sourceConfigurations.isEmpty)
  }

  func testDuplicateActionIDsAreRejectedOrDeduplicated() {
    let duplicateActions = [
      InboxAction(id: "open", title: "Open first"),
      InboxAction(id: "open", title: "Open second"),
    ]
    let store = InboxStore()
    var message = item("one")
    message = InboxItem(
      id: message.id,
      title: message.title,
      body: message.body,
      format: message.format,
      timestamp: message.timestamp,
      category: message.category,
      severity: message.severity,
      unread: message.unread,
      dismissible: message.dismissible,
      actions: duplicateActions
    )

    store.replace(source: "GitLab", items: [message])
    store.configure(source: "GitLab", actions: duplicateActions)

    XCTAssertTrue(store.presentedItems.isEmpty)
    XCTAssertEqual(
      store.sourceConfigurations.first?.actions,
      [InboxAction(id: "open", title: "Open first")]
    )
  }

  func testPersistedStateIsFormattedAndDeterministic() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateURL = directory.appendingPathComponent("inbox-state.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let persistence = InboxStatePersistence(
      fileURL: stateURL,
      logger: ProcessLogger(label: "inbox.persistence.test", minimumLevel: .error)
    )
    let state = InboxPersistedState(
      readItemIDs: ["GitHub\u{1f}z/item", "GitHub\u{1f}a/item"],
      unreadItemIDs: ["GitLab\u{1f}one"],
      dismissedItemIDs: []
    )

    persistence.save(state)

    let text = try String(contentsOf: stateURL, encoding: .utf8)
    XCTAssertTrue(text.hasSuffix("\n"))
    XCTAssertTrue(text.contains("\n  \"dismissedItemIDs\" : ["))
    XCTAssertTrue(text.contains("GitHub\\u001fa/item"))
    XCTAssertTrue(text.contains("GitHub\\u001fz/item"))
    XCTAssertFalse(text.contains("z\\/item"))
    XCTAssertLessThan(
      try XCTUnwrap(text.range(of: "GitHub\\u001fa/item")?.lowerBound),
      try XCTUnwrap(text.range(of: "GitHub\\u001fz/item")?.lowerBound)
    )
    XCTAssertEqual(persistence.load(), state)
  }

  private func item(
    _ id: String,
    title: String? = nil,
    timestamp: TimeInterval = 0,
    category: String? = nil,
    dismissible: Bool? = nil
  ) -> InboxItem {
    InboxItem(
      id: id,
      title: title ?? id,
      body: nil,
      format: nil,
      timestamp: timestamp,
      category: category,
      severity: nil,
      unread: nil,
      dismissible: dismissible,
      actions: nil
    )
  }
}
