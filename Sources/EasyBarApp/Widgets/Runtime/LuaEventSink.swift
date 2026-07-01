import EasyBarShared
import Foundation

/// Serializes event delivery into the Lua runtime off the EventHub hot path.
final class LuaEventSink {
  private let runtime: LuaRuntime
  private let logger: ProcessLogger

  /// Creates one Lua event sink.
  init(
    runtime: LuaRuntime,
    logger: ProcessLogger
  ) {
    self.runtime = runtime
    self.logger = logger
  }

  /// Enqueues one event payload for Lua delivery.
  func enqueue(_ payload: EasyBarEventPayload) {
    Task { [runtime, logger] in
      guard let encoded = Self.encodedPayload(payload) else {
        logger.error(
          "failed to encode lua event payload",
          .field("name", payload.eventName),
        )
        return
      }

      logger.trace("sent event to lua socket", .field("bytes", encoded.utf8.count))
      await runtime.send(encoded)
    }
  }

  /// Returns the encoded Lua payload string.
  private static func encodedPayload(_ payload: EasyBarEventPayload) -> String? {
    return encodeJSON(payload.toDictionary())
  }

  /// Encodes one event payload as JSON for the Lua runtime.
  private static func encodeJSON(_ payload: [String: Any]) -> String? {
    guard
      let data = try? JSONSerialization.data(withJSONObject: payload),
      let string = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return string
  }
}
