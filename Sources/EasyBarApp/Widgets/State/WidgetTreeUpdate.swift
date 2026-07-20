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
  let arguments: [String]?
  let sync: Bool?
  let delaySeconds: TimeInterval?
  let timeoutSeconds: TimeInterval?
  let maxOutputBytes: Int?
  let source: String?
  let items: [InboxItem]?
  let actions: [InboxAction]?

  enum CodingKeys: String, CodingKey {
    case protocolVersion
    case type
    case root
    case nodes
    case events
    case token
    case command
    case arguments
    case sync
    case delaySeconds
    case timeoutSeconds
    case maxOutputBytes
    case source
    case items
    case actions
  }

  enum Kind: String, Codable, Sendable {
    case subscriptions
    case ready
    case tree
    case clearRoot = "clear_root"
    case commandRequest = "command_request"
    case commandCancel = "command_cancel"
    case timerRequest = "timer_request"
    case timerCancel = "timer_cancel"
    case inboxReplace = "inbox_replace"
    case inboxClear = "inbox_clear"
    case inboxConfigure = "inbox_configure"
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

  /// Returns the asynchronous command token to cancel when present.
  var commandCancelToken: String? {
    guard type == .commandCancel else { return nil }
    return token
  }

  /// Returns the timer token to cancel when present.
  var timerCancelToken: String? {
    guard type == .timerCancel else { return nil }
    return token
  }

  /// Returns the timer request payload when present.
  var timerRequestPayload: (token: String, delaySeconds: TimeInterval)? {
    guard type == .timerRequest, let token, let delaySeconds else { return nil }
    return (token: token, delaySeconds: delaySeconds)
  }

  var inboxReplacePayload: InboxSourceSnapshot? {
    guard type == .inboxReplace, let source, let items else { return nil }
    return InboxSourceSnapshot(source: source, items: items)
  }

  var inboxClearSource: String? {
    guard type == .inboxClear else { return nil }
    return source
  }

  var inboxConfigurationPayload: InboxSourceConfiguration? {
    guard type == .inboxConfigure, let source, let actions else { return nil }
    return InboxSourceConfiguration(source: source, actions: actions)
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
      arguments: [String]?,
      invocation: LuaCommandInvocation,
      isSynchronous: Bool,
      timeoutSeconds: TimeInterval?,
      maxOutputBytes: Int?
    )?
  {
    guard let token, let sync else { return nil }

    let invocation: LuaCommandInvocation
    if let command, !command.isEmpty, arguments == nil {
      invocation = .shell(command)
    } else if command == nil, let arguments, !arguments.isEmpty {
      invocation = .executable(arguments)
    } else {
      return nil
    }

    let displayCommand: String
    let directArguments: [String]?
    switch invocation {
    case .shell(let command):
      displayCommand = command
      directArguments = nil
    case .executable(let arguments):
      displayCommand = arguments.joined(separator: " ")
      directArguments = arguments
    }

    return (
      token: token,
      command: displayCommand,
      arguments: directArguments,
      invocation: invocation,
      isSynchronous: sync,
      timeoutSeconds: timeoutSeconds,
      maxOutputBytes: maxOutputBytes
    )
  }
}
