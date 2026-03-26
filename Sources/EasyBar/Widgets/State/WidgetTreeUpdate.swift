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

  /// Returns whether this update contains subscriptions.
  var isSubscriptions: Bool {
    type == .subscriptions
  }

  /// Returns whether this update is the runtime ready signal.
  var isReady: Bool {
    type == .ready
  }

  /// Returns whether this update contains a widget tree.
  var isTree: Bool {
    type == .tree
  }

  /// Returns the subscribed event names or an empty list.
  var subscribedEvents: [String] {
    events ?? []
  }

  /// Returns whether this update includes a decoded tree payload.
  var hasTreePayload: Bool {
    root != nil && nodes != nil
  }

  /// Returns the decoded tree payload when present.
  var treePayload: (root: String, nodes: [WidgetNodeState])? {
    guard hasTreePayload else { return nil }
    guard let root else { return nil }
    guard let nodes else { return nil }
    return (root: root, nodes: nodes)
  }
}
