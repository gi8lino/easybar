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

  func testRelationshipIndexesTrackReplacementAndClear() throws {
    let store = WidgetStore()
    let root = try makeNode(id: "root", root: "root", text: "root")
    let child = try makeNode(id: "child", root: "root", text: "child", parent: "root")
    let anchor = try makeNode(
      id: "anchor",
      root: "root",
      text: "anchor",
      parent: "root",
      role: "popup-anchor"
    )
    let popup = try makeNode(
      id: "popup",
      root: "root",
      text: "popup",
      parent: "root",
      role: "popup-content"
    )

    store.apply(root: "root", nodes: [popup, child, root, anchor])

    XCTAssertEqual(store.topLevelNodes(for: .right), [root])
    XCTAssertEqual(store.children(of: "root"), [child])
    XCTAssertEqual(store.anchorChildren(of: "root"), [anchor])
    XCTAssertEqual(store.popupChildren(of: "root"), [popup])

    store.apply(root: "root", nodes: [root])

    XCTAssertTrue(store.children(of: "root").isEmpty)
    XCTAssertTrue(store.anchorChildren(of: "root").isEmpty)
    XCTAssertTrue(store.popupChildren(of: "root").isEmpty)
  }

  private func makeNode(
    id: String,
    root: String,
    text: String,
    parent: String? = nil,
    role: String? = nil
  ) throws -> WidgetNodeState {
    let parentField = parent.map { "\"parent\": \"\($0)\"," } ?? ""
    let roleField = role.map { "\"role\": \"\($0)\"," } ?? ""
    let payload = """
      {
        "id": "\(id)",
        "root": "\(root)",
        \(parentField)
        \(roleField)
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
