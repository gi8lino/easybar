import Foundation

/// Mutable Lua runtime handshake state tracked by the widget engine.
struct WidgetRuntimeState {
  /// Event names currently requested by Lua widgets.
  var requiredEvents = Set<String>()
  /// Whether the Lua runtime sent its ready handshake.
  var isReady = false
  /// Whether the Lua runtime published its subscribed events.
  var hasSubscriptions = false
  /// Whether initial events have already been emitted.
  var didEmitInitialEvents = false

  /// Returns whether the engine can emit the initial event batch.
  var canEmitInitialEvents: Bool {
    isReady && hasSubscriptions && !didEmitInitialEvents
  }

  /// Resets all tracked runtime handshake state.
  mutating func reset() {
    requiredEvents.removeAll()
    isReady = false
    hasSubscriptions = false
    didEmitInitialEvents = false
  }
}
