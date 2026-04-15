import Foundation
import SwiftUI

final class WidgetStore: ObservableObject {

  static let shared = WidgetStore()

  @Published private(set) var nodes: [WidgetNodeState] = []

  private let stateQueue = DispatchQueue(label: "easybar.widget-store.state")
  private var nodeMap: [String: WidgetNodeState] = [:]
  private var rootIndex: [String: Set<String>] = [:]

  func apply(root: String, nodes updates: [WidgetNodeState]) {
    let renderedNodes = stateQueue.sync { () -> [WidgetNodeState] in
      for id in existingIDs(for: root) {
        nodeMap.removeValue(forKey: id)
      }

      rootIndex[root] = storeNodes(updates)
      return nodeMap.values.sorted(by: sortNodes)
    }

    publish(nodes: renderedNodes)
  }

  func clear() {
    stateQueue.sync {
      nodeMap.removeAll()
      rootIndex.removeAll()
    }

    publish(nodes: [])
  }

  func topLevelNodes(for position: WidgetPosition) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.isTopLevel && $0.position == position
    }
  }

  func children(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && !$0.isPopupAnchor && !$0.isPopupContent
    }
  }

  func anchorChildren(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && $0.isPopupAnchor
    }
  }

  func popupChildren(of parentID: String) -> [WidgetNodeState] {
    sortedPublishedNodes {
      $0.parent == parentID && $0.isPopupContent
    }
  }

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

  /// Publishes the current rendered nodes on the main queue.
  private func publish(nodes: [WidgetNodeState]) {
    if Thread.isMainThread {
      self.nodes = nodes
      return
    }

    DispatchQueue.main.async {
      self.nodes = nodes
    }
  }
}
