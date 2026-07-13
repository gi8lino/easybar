import Foundation

/// Protocol version expected between EasyBar and the Lua widget runtime.
let easyBarLuaRuntimeProtocolVersion = 1

/// Decoded message emitted by the Lua widget runtime.
struct WidgetTreeUpdate: Codable, Sendable {

  let protocolVersion: Int?
  let type: Kind
  let root: String?
  let nodes: [WidgetNodeState]?
  let events: [String]?
  let token: String?
  let command: String?
  let sync: Bool?
  let timeoutSeconds: TimeInterval?
  let maxOutputBytes: Int?

  enum CodingKeys: String, CodingKey {
    case protocolVersion = "protocol_version"
    case type
    case root
    case nodes
    case events
    case token
    case command
    case sync
    case timeoutSeconds = "timeout_seconds"
    case maxOutputBytes = "max_output_bytes"
  }

  enum Kind: String, Codable, Sendable {
    case subscriptions
    case ready
    case tree
    case clearRoot = "clear_root"
    case commandRequest = "command_request"
  }

  /// Returns whether this update contains subscriptions.
  var isSubscriptions: Bool {
    return type == .subscriptions
  }

  /// Returns whether this update uses the expected host/runtime protocol version.
  var isSupportedProtocolVersion: Bool {
    return protocolVersion == easyBarLuaRuntimeProtocolVersion
  }

  /// Returns whether this update is the runtime ready signal.
  var isReady: Bool {
    return type == .ready
  }

  /// Returns whether this update contains a widget tree.
  var isTree: Bool {
    return type == .tree
  }

  /// Returns whether this update explicitly clears one rendered root.
  var isClearRoot: Bool {
    return type == .clearRoot
  }

  /// Returns whether this update is a host command execution request.
  var isCommandRequest: Bool {
    return type == .commandRequest
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

  /// Returns the root identifier to clear when present.
  var clearRootID: String? {
    guard isClearRoot else { return nil }
    return root
  }

  /// Returns the decoded command request payload when present.
  var commandRequestPayload:
    (
      token: String,
      command: String,
      isSynchronous: Bool,
      timeoutSeconds: TimeInterval?,
      maxOutputBytes: Int?
    )?
  {
    guard let token, let command, let sync else { return nil }
    return (
      token: token,
      command: command,
      isSynchronous: sync,
      timeoutSeconds: timeoutSeconds,
      maxOutputBytes: maxOutputBytes
    )
  }
}
