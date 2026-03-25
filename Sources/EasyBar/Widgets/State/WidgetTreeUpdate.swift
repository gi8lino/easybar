import Foundation

struct WidgetTreeUpdate: Codable {
    let type: Kind
    let root: String?
    let nodes: [WidgetNodeState]?
    let events: [String]?

    enum Kind: String, Codable {
        case subscriptions
        case ready
        case tree
    }

    /// Returns the subscribed event names or an empty list.
    var subscribedEvents: [String] {
        events ?? []
    }

    /// Returns the decoded tree payload when present.
    var treePayload: (root: String, nodes: [WidgetNodeState])? {
        guard let root, let nodes else { return nil }
        return (root, nodes)
    }
}
