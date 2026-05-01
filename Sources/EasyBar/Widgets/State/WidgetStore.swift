import Foundation
import SwiftUI

@MainActor
final class WidgetStore: ObservableObject {
  static let shared = WidgetStore()

  @Published private(set) var nodes: [WidgetNodeState] = []

  private var nodeMap: [String: WidgetNodeState] = [:]
  private var rootIndex: [String: Set<String>] = [:]

  /// Handles apply.
  func apply(root: String, nodes updates: [WidgetNodeState]) {
    for id in existingIDs(for: root) {
      nodeMap.removeValue(forKey: id)
    }

    rootIndex[root] = storeNodes(updates)
    nodes = nodeMap.values.sorted(by: sortNodes)
  }

  /// Handles clear.
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

  /// Handles top level nodes.
  func topLevelNodes(for position: WidgetPosition) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.isTopLevel && $0.position == position
    }
  }

  /// Handles children.
  func children(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && !$0.isPopupAnchor && !$0.isPopupContent
    }
  }

  /// Handles anchor children.
  func anchorChildren(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && $0.isPopupAnchor
    }
  }

  /// Handles popup children.
  func popupChildren(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && $0.isPopupContent
    }
  }

  /// Handles sort nodes.
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
    rootIndex[root] ?? []
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
