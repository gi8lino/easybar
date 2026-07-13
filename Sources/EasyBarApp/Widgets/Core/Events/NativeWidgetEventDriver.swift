import Foundation

/// Small shared helper that removes repeated event-observer boilerplate in native widgets.
enum NativeWidgetEventDriver {

  /// Starts observing EasyBar events and routes app events before widget-local events.
  static func start(
    observer: EasyBarEventObserver,
    eventNames: Set<String>,
    widgetTargetIDs: Set<String> = [],
    appHandler: @escaping @MainActor @Sendable (EasyBarEventPayload) -> Bool,
    widgetHandler: @escaping @MainActor @Sendable (EasyBarEventPayload) -> Void
  ) {
    observer.start(eventNames: eventNames, widgetTargetIDs: widgetTargetIDs) { payload in
      if appHandler(payload) {
        return
      }

      widgetHandler(payload)
    }
  }

  /// Starts observing EasyBar events with a single raw handler.
  static func start(
    observer: EasyBarEventObserver,
    eventNames: Set<String>,
    handler: @escaping @MainActor @Sendable (EasyBarEventPayload) -> Void
  ) {
    observer.start(eventNames: eventNames, handler: handler)
  }
}
