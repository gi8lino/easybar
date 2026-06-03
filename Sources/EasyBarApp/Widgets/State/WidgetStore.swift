import Foundation
import SwiftUI

/// Main-actor store containing all currently rendered widget nodes.
@MainActor
final class WidgetStore: ObservableObject {
  static var shared = WidgetStore()

  @Published private(set) var nodes: [WidgetNodeState] = []

  private var nodeMap: [String: WidgetNodeState] = [:]
  private var rootIndex: [String: Set<String>] = [:]

  /// Replaces all nodes for one widget root.
  func apply(root: String, nodes updates: [WidgetNodeState]) {
    for id in existingIDs(for: root) {
      nodeMap.removeValue(forKey: id)
    }

    rootIndex[root] = storeNodes(updates)
    nodes = nodeMap.values.sorted(by: sortNodes)
  }

  /// Clears all rendered widget nodes.
  func clear() {
    nodeMap.removeAll()
    rootIndex.removeAll()
    nodes = []
  }

  /// Handles clear.
  func clear(roots: Set<String>) {
    guard !roots.isEmpty else { return }

    for root in roots {
      for id in existingIDs(for: root) {
        nodeMap.removeValue(forKey: id)
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
  private func storeNodes(_ updates: [WidgetNodeState]) -> Set<String> {
    var ids = Set<String>()

    for node in updates {
      nodeMap[node.id] = node
      ids.insert(node.id)
    }

    return ids
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
