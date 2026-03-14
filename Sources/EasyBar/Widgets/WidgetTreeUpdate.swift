import Foundation

struct WidgetTreeUpdate: Codable {
    let type: String
    let root: String?
    let nodes: [WidgetNodeState]?
}
