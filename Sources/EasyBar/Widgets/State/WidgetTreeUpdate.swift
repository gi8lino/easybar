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
}
