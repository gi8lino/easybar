import Foundation

/// Decoded host-side classification of one Lua runtime protocol message.
enum WidgetRuntimeMessage {
  case subscriptions(Set<String>)
  case ready
  case tree(root: String, nodes: [WidgetNodeState])
  case clearRoot(String)
  case commandRequest(
    token: String,
    command: String,
    isSynchronous: Bool,
    timeoutSeconds: TimeInterval?,
    maxOutputBytes: Int?
  )
  case commandCancel(token: String)
  case inboxReplace(InboxSourceSnapshot)
  case inboxClear(source: String)
}

/// Decodes and classifies structured messages emitted by the Lua widget runtime.
struct WidgetRuntimeProtocolDecoder {
  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }()

  /// Decodes one raw protocol line into a typed runtime message.
  func decodeMessage(from line: String) throws -> WidgetRuntimeMessage {
    let update = try decodeUpdate(from: line)

    guard update.isSupportedProtocolVersion else {
      throw WidgetRuntimeProtocolError.unsupportedProtocolVersion(update.protocolVersion)
    }

    switch update.type {
    case .subscriptions:
      return .subscriptions(Set(update.subscribedEvents))
    case .ready:
      return .ready
    case .tree:
      guard let tree = update.treePayload else {
        throw WidgetRuntimeProtocolError.invalidPayload(
          "unknown lua message"
        )
      }
      return .tree(root: tree.root, nodes: tree.nodes)
    case .clearRoot:
      guard let rootID = update.clearRootID else {
        throw WidgetRuntimeProtocolError.invalidPayload(
          "invalid lua clear-root update"
        )
      }
      return .clearRoot(rootID)
    case .commandRequest:
      guard let request = update.commandRequestPayload else {
        throw WidgetRuntimeProtocolError.invalidPayload(
          "invalid lua command request"
        )
      }

      if let timeoutSeconds = request.timeoutSeconds,
        !timeoutSeconds.isFinite || timeoutSeconds <= 0
      {
        throw WidgetRuntimeProtocolError.invalidPayload(
          "invalid lua command timeout override"
        )
      }

      if let maxOutputBytes = request.maxOutputBytes,
        maxOutputBytes <= 0
      {
        throw WidgetRuntimeProtocolError.invalidPayload(
          "invalid lua command output override"
        )
      }

      return .commandRequest(
        token: request.token,
        command: request.command,
        isSynchronous: request.isSynchronous,
        timeoutSeconds: request.timeoutSeconds,
        maxOutputBytes: request.maxOutputBytes
      )
    case .commandCancel:
      guard let token = update.commandCancelToken, !token.isEmpty else {
        throw WidgetRuntimeProtocolError.invalidPayload(
          "invalid lua command cancellation request"
        )
      }
      return .commandCancel(token: token)
    case .inboxReplace:
      guard let snapshot = update.inboxReplacePayload,
        !snapshot.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw WidgetRuntimeProtocolError.invalidPayload("invalid inbox replacement")
      }
      return .inboxReplace(snapshot)
    case .inboxClear:
      guard let source = update.inboxClearSource,
        !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        throw WidgetRuntimeProtocolError.invalidPayload("invalid inbox clear")
      }
      return .inboxClear(source: source)
    }
  }

  /// Decodes one structured runtime update line.
  private func decodeUpdate(from line: String) throws -> WidgetTreeUpdate {
    guard let data = line.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: [], debugDescription: "invalid utf8")
      )
    }

    return try decoder.decode(WidgetTreeUpdate.self, from: data)
  }
}

/// Errors returned while decoding the Lua runtime protocol.
enum WidgetRuntimeProtocolError: Error {
  case unsupportedProtocolVersion(Int?)
  case invalidPayload(String)
}
