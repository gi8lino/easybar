import Foundation

/// Serializes event delivery into the Lua runtime off the EventHub hot path.
final class LuaEventSink {
  private let runtime = LuaRuntime.shared
  private let queue = DispatchQueue(label: "easybar.lua-event-sink")

  /// Enqueues one event payload for Lua delivery.
  func enqueue(_ payload: EasyBarEventPayload) {
    queue.async { [runtime] in
      guard let encoded = Self.encodedPayload(payload) else {
        easybarLog.error("failed to encode lua event payload name=\(payload.eventName)")
        return
      }

      easybarLog.trace("sent to lua stdin: \(encoded)")

      Task {
        await runtime.send(encoded)
      }
    }
  }

  /// Returns the encoded Lua payload string.
  private static func encodedPayload(_ payload: EasyBarEventPayload) -> String? {
    encodeJSON(payload.toDictionary())
  }

  /// Encodes one event payload as JSON for the Lua runtime.
  private static func encodeJSON(_ payload: [String: Any]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
      let string = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return string
  }
}
