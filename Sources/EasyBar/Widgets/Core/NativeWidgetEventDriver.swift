import Foundation

/// Small shared helper that removes repeated event-observer boilerplate in native widgets.
enum NativeWidgetEventDriver {

  /// Starts observing EasyBar events and routes app events before widget-local events.
  static func start(
    observer: EasyBarEventObserver,
    appHandler: @escaping (EasyBarEventPayload) -> Bool,
    widgetHandler: @escaping (EasyBarEventPayload) -> Void
  ) {
    observer.start { payload in
      if appHandler(payload) {
        return
      }

      widgetHandler(payload)
    }
  }

  /// Starts observing EasyBar events with a single raw handler.
  static func start(
    observer: EasyBarEventObserver,
    handler: @escaping (EasyBarEventPayload) -> Void
  ) {
    observer.start(handler: handler)
  }
}
