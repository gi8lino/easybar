import Foundation
import SwiftUI

final class WidgetStore: ObservableObject {

    static let shared = WidgetStore()

    @Published private(set) var nodes: [WidgetNodeState] = []

    private var nodeMap: [String: WidgetNodeState] = [:]
    private var rootIndex: [String: Set<String>] = [:]

    func apply(root: String, nodes updates: [WidgetNodeState]) {
        let oldIDs = rootIndex[root] ?? []

        for id in oldIDs {
            nodeMap.removeValue(forKey: id)
        }

        var newIDs = Set<String>()

        for node in updates {
            nodeMap[node.id] = node
            newIDs.insert(node.id)
        }

        rootIndex[root] = newIDs

        render()
    }

    func clear() {
        nodeMap.removeAll()
        rootIndex.removeAll()

        DispatchQueue.main.async {
            self.nodes = []
        }
    }

    func topLevelNodes(for position: String) -> [WidgetNodeState] {
        nodes
            .filter { ($0.parent == nil || $0.parent == "") && $0.position == position }
            .sorted(by: sortNodes)
    }

    func children(of parentID: String) -> [WidgetNodeState] {
        nodes
            .filter { $0.parent == parentID && ($0.role ?? "") != "popup-anchor" }
            .sorted(by: sortNodes)
    }

    func anchorChildren(of parentID: String) -> [WidgetNodeState] {
        nodes
            .filter { $0.parent == parentID && ($0.role ?? "") == "popup-anchor" }
            .sorted(by: sortNodes)
    }

    private func render() {
        let sorted = nodeMap.values.sorted(by: sortNodes)

        DispatchQueue.main.async {
            withAnimation(.linear(duration: 0.08)) {
                self.nodes = sorted
            }
        }
    }

    private func sortNodes(_ lhs: WidgetNodeState, _ rhs: WidgetNodeState) -> Bool {
        if lhs.position != rhs.position {
            return lhs.position < rhs.position
        }

        if lhs.order != rhs.order {
            return lhs.order < rhs.order
        }

        return lhs.id < rhs.id
    }
}
