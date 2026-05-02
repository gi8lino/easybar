import Foundation

/// Decoded message emitted by the Lua widget runtime.
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
    return type == .subscriptions
  }

  /// Returns whether this update is the runtime ready signal.
  var isReady: Bool {
    return type == .ready
  }

  /// Returns whether this update contains a widget tree.
  var isTree: Bool {
    return type == .tree
  }

  /// Returns the subscribed event names or an empty list.
  var subscribedEvents: [String] {
    return events ?? []
  }

  /// Returns whether this update includes a decoded tree payload.
  var hasTreePayload: Bool {
    return root != nil && nodes != nil
  }

  /// Returns the decoded tree payload when present.
  var treePayload: (root: String, nodes: [WidgetNodeState])? {
    guard let root, let nodes else { return nil }
    return (root: root, nodes: nodes)
  }
}
