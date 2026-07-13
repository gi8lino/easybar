import Foundation
import SwiftUI

/// Main-actor store containing all currently rendered widget nodes.
@MainActor
final class WidgetStore: ObservableObject {
  enum Owner: Hashable {
    case native(root: String)
    case scripted(root: String)

    var root: String {
      switch self {
      case .native(let root), .scripted(let root):
        return root
      }
    }
  }

  struct ApplyResult: Equatable {
    var duplicateNodeIDs = Set<String>()
    var mismatchedRootNodeIDs = Set<String>()
    var conflictingNodeIDs = Set<String>()
    var invalidParentNodeIDs = Set<String>()

    var rejectedNodeIDs: Set<String> {
      duplicateNodeIDs.union(mismatchedRootNodeIDs).union(conflictingNodeIDs)
        .union(invalidParentNodeIDs)
    }
  }

  @Published private(set) var nodes: [WidgetNodeState] = []

  private var nodeMap: [String: WidgetNodeState] = [:]
  private var rootIndex: [Owner: Set<String>] = [:]
  private var nodeOwners: [String: Owner] = [:]
  private var topLevelNodesByPosition: [WidgetPosition: [WidgetNodeState]] = [:]
  private var childNodesByParentID: [String: [WidgetNodeState]] = [:]
  private var anchorNodesByParentID: [String: [WidgetNodeState]] = [:]
  private var popupNodesByParentID: [String: [WidgetNodeState]] = [:]

  /// Replaces all nodes for one widget root.
  @discardableResult
  func apply(owner: Owner, nodes updates: [WidgetNodeState]) -> ApplyResult {
    let result = validateNodes(updates, owner: owner)
    guard result.rejectedNodeIDs.isEmpty else { return result }

    for id in existingIDs(for: owner) {
      removeNode(id, ownedBy: owner)
    }

    let ids = Set(updates.map(\.id))
    for node in updates {
      nodeMap[node.id] = node
      nodeOwners[node.id] = owner
    }

    rootIndex[owner] = ids
    rebuildPublishedState()
    return result
  }

  /// Clears all rendered widget nodes.
  func clear() {
    nodeMap.removeAll()
    rootIndex.removeAll()
    nodeOwners.removeAll()
    rebuildPublishedState()
  }

  /// Handles clear.
  func clear(owners: Set<Owner>) {
    guard !owners.isEmpty else { return }

    for owner in owners {
      for id in existingIDs(for: owner) {
        removeNode(id, ownedBy: owner)
      }

      rootIndex.removeValue(forKey: owner)
    }

    rebuildPublishedState()
  }

  /// Returns top-level nodes for one bar position.
  func topLevelNodes(for position: WidgetPosition) -> [WidgetNodeState] {
    topLevelNodesByPosition[position] ?? []
  }

  /// Returns non-popup children for one parent node.
  func children(of parentID: String) -> [WidgetNodeState] {
    childNodesByParentID[parentID] ?? []
  }

  /// Returns popup anchor children for one parent node.
  func anchorChildren(of parentID: String) -> [WidgetNodeState] {
    anchorNodesByParentID[parentID] ?? []
  }

  /// Returns popup content children for one parent node.
  func popupChildren(of parentID: String) -> [WidgetNodeState] {
    popupNodesByParentID[parentID] ?? []
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
  private func existingIDs(for owner: Owner) -> Set<String> {
    return rootIndex[owner] ?? []
  }

  /// Validates a complete replacement without mutating the current store.
  private func validateNodes(
    _ updates: [WidgetNodeState],
    owner: Owner
  ) -> ApplyResult {
    var ids = Set<String>()
    var result = ApplyResult()
    let updateIDs = Set(updates.lazy.filter { $0.root == owner.root }.map(\.id))

    for node in updates {
      guard node.root == owner.root else {
        result.mismatchedRootNodeIDs.insert(node.id)
        continue
      }

      guard ids.insert(node.id).inserted else {
        result.duplicateNodeIDs.insert(node.id)
        continue
      }

      if case .scripted = owner,
        let parentID = node.parent,
        !parentID.isEmpty,
        !updateIDs.contains(parentID)
      {
        result.invalidParentNodeIDs.insert(node.id)
        continue
      }

      if let existingOwner = nodeOwners[node.id], existingOwner != owner {
        result.conflictingNodeIDs.insert(node.id)
      }
    }

    return result
  }

  /// Removes a node only when the requesting root still owns it.
  private func removeNode(_ id: String, ownedBy owner: Owner) {
    guard nodeOwners[id] == owner else { return }
    nodeMap.removeValue(forKey: id)
    nodeOwners.removeValue(forKey: id)
  }

  /// Rebuilds ordered lookup indexes after one atomic store mutation.
  private func rebuildPublishedState() {
    nodes = nodeMap.values.sorted(by: sortNodes)
    topLevelNodesByPosition.removeAll(keepingCapacity: true)
    childNodesByParentID.removeAll(keepingCapacity: true)
    anchorNodesByParentID.removeAll(keepingCapacity: true)
    popupNodesByParentID.removeAll(keepingCapacity: true)

    for node in nodes {
      guard let parentID = node.parent, !parentID.isEmpty else {
        topLevelNodesByPosition[node.position, default: []].append(node)
        continue
      }

      if node.isPopupAnchor {
        anchorNodesByParentID[parentID, default: []].append(node)
      } else if node.isPopupContent {
        popupNodesByParentID[parentID, default: []].append(node)
      } else {
        childNodesByParentID[parentID, default: []].append(node)
      }
    }
  }
}
