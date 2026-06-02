import Foundation

/// Decoded host-side classification of one Lua runtime protocol message.
enum WidgetRuntimeMessage {
  case subscriptions(Set<String>)
  case ready
  case tree(root: String, nodes: [WidgetNodeState])
  case clearRoot(String)
  case commandRequest(token: String, command: String, isSynchronous: Bool)
}

/// Decodes and classifies structured messages emitted by the Lua widget runtime.
struct WidgetRuntimeProtocolDecoder {
  private let decoder = JSONDecoder()

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
          "unknown lua message: \(line)"
        )
      }
      return .tree(root: tree.root, nodes: tree.nodes)
    case .clearRoot:
      guard let rootID = update.clearRootID else {
        throw WidgetRuntimeProtocolError.invalidPayload(
          "invalid lua clear-root update: \(line)"
        )
      }
      return .clearRoot(rootID)
    case .commandRequest:
      guard let request = update.commandRequestPayload else {
        throw WidgetRuntimeProtocolError.invalidPayload(
          "invalid lua command request: \(line)"
        )
      }
      return .commandRequest(
        token: request.token,
        command: request.command,
        isSynchronous: request.isSynchronous
      )
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
