import Foundation
import SwiftUI

/// Main-actor store containing all currently rendered widget nodes.
@MainActor
final class WidgetStore: ObservableObject {
  struct ApplyResult: Equatable {
    var duplicateNodeIDs = Set<String>()
    var mismatchedRootNodeIDs = Set<String>()
    var conflictingNodeIDs = Set<String>()

    var rejectedNodeIDs: Set<String> {
      duplicateNodeIDs.union(mismatchedRootNodeIDs).union(conflictingNodeIDs)
    }
  }

  @Published private(set) var nodes: [WidgetNodeState] = []

  private var nodeMap: [String: WidgetNodeState] = [:]
  private var rootIndex: [String: Set<String>] = [:]
  private var nodeOwners: [String: String] = [:]

  /// Replaces all nodes for one widget root.
  @discardableResult
  func apply(root: String, nodes updates: [WidgetNodeState]) -> ApplyResult {
    for id in existingIDs(for: root) {
      removeNode(id, ownedBy: root)
    }

    let stored = storeNodes(updates, root: root)
    rootIndex[root] = stored.ids
    nodes = nodeMap.values.sorted(by: sortNodes)
    return stored.result
  }

  /// Clears all rendered widget nodes.
  func clear() {
    nodeMap.removeAll()
    rootIndex.removeAll()
    nodeOwners.removeAll()
    nodes = []
  }

  /// Handles clear.
  func clear(roots: Set<String>) {
    guard !roots.isEmpty else { return }

    for root in roots {
      for id in existingIDs(for: root) {
        removeNode(id, ownedBy: root)
      }

      rootIndex.removeValue(forKey: root)
    }

    nodes = nodeMap.values.sorted(by: sortNodes)
  }

  /// Returns top-level nodes for one bar position.
  func topLevelNodes(for position: WidgetPosition) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.isTopLevel && $0.position == position
    }
  }

  /// Returns non-popup children for one parent node.
  func children(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && !$0.isPopupAnchor && !$0.isPopupContent
    }
  }

  /// Returns popup anchor children for one parent node.
  func anchorChildren(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && $0.isPopupAnchor
    }
  }

  /// Returns popup content children for one parent node.
  func popupChildren(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && $0.isPopupContent
    }
  }

  /// Sorts nodes by position, order, and id.
  private func sortNodes(_ lhs: WidgetNodeState, _ rhs: WidgetNodeState) -> Bool {
    if lhs.position != rhs.position {
      return lhs.position.rawValue < rhs.position.rawValue
    }

    if lhs.order != rhs.order {
      return lhs.order < rhs.order
    }

    return lhs.id < rhs.id
  }

  /// Returns all stored node ids for one widget root.
  private func existingIDs(for root: String) -> Set<String> {
    return rootIndex[root] ?? []
  }

  /// Stores updated nodes and returns their ids.
  private func storeNodes(
    _ updates: [WidgetNodeState],
    root: String
  ) -> (ids: Set<String>, result: ApplyResult) {
    var ids = Set<String>()
    var result = ApplyResult()

    for node in updates {
      guard node.root == root else {
        result.mismatchedRootNodeIDs.insert(node.id)
        continue
      }

      guard ids.insert(node.id).inserted else {
        result.duplicateNodeIDs.insert(node.id)
        continue
      }

      if let owner = nodeOwners[node.id], owner != root {
        ids.remove(node.id)
        result.conflictingNodeIDs.insert(node.id)
        continue
      }

      nodeMap[node.id] = node
      nodeOwners[node.id] = root
    }

    return (ids, result)
  }

  /// Removes a node only when the requesting root still owns it.
  private func removeNode(_ id: String, ownedBy root: String) {
    guard nodeOwners[id] == root else { return }
    nodeMap.removeValue(forKey: id)
    nodeOwners.removeValue(forKey: id)
  }

  /// Returns sorted published nodes matching the given predicate.
  private func sortedPublishedNodes(
    matching predicate: (WidgetNodeState) -> Bool
  ) -> [WidgetNodeState] {
    nodes
      .filter(predicate)
      .sorted(by: sortNodes)
  }
}
