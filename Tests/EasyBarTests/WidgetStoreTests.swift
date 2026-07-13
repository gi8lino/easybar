import XCTest

@testable import EasyBarApp

@MainActor
final class WidgetStoreTests: XCTestCase {
  func testCrossRootNodeCollisionDoesNotOverwriteOrDeleteOwner() throws {
    let store = WidgetStore()
    let original = try makeNode(id: "shared", root: "first", text: "original")
    let collision = try makeNode(id: "shared", root: "second", text: "replacement")

    store.apply(root: "first", nodes: [original])
    let result = store.apply(root: "second", nodes: [collision])
    store.clear(roots: ["second"])

    XCTAssertEqual(result.conflictingNodeIDs, ["shared"])
    XCTAssertEqual(store.topLevelNodes(for: .right), [original])
  }

  func testApplyRejectsMismatchedRootsAndDuplicateIDs() throws {
    let store = WidgetStore()
    let first = try makeNode(id: "duplicate", root: "expected", text: "first")
    let duplicate = try makeNode(id: "duplicate", root: "expected", text: "second")
    let mismatch = try makeNode(id: "mismatch", root: "other", text: "mismatch")

    let result = store.apply(root: "expected", nodes: [first, duplicate, mismatch])

    XCTAssertEqual(result.duplicateNodeIDs, ["duplicate"])
    XCTAssertEqual(result.mismatchedRootNodeIDs, ["mismatch"])
    XCTAssertEqual(store.topLevelNodes(for: .right), [first])
  }

  private func makeNode(id: String, root: String, text: String) throws -> WidgetNodeState {
    let payload = """
      {
        "id": "\(id)",
        "root": "\(root)",
        "kind": "item",
        "position": "right",
        "order": 0,
        "icon": "",
        "text": "\(text)",
        "visible": true
      }
      """
    return try JSONDecoder().decode(WidgetNodeState.self, from: Data(payload.utf8))
  }
}
