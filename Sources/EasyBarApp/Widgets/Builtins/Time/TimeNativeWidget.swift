import Foundation

/// Native time widget.
@MainActor
final class TimeNativeWidget: NativeWidget {

  let rootID = "builtin_time"
  let widgetStore: WidgetStore
  private let config: Config.TimeBuiltinConfig
  private let eventHub: EventHub
  private lazy var controller = FormattedClockNativeWidgetController(
    rootID: rootID,
    widgetStore: widgetStore,
    eventHub: eventHub
  ) { [config] in
    .init(
      placement: config.placement,
      style: config.style,
      format: config.format
    )
  }

  /// Creates the native time widget from an immutable config section.
  init(config: Config.TimeBuiltinConfig, widgetStore: WidgetStore, eventHub: EventHub) {
    self.config = config
    self.widgetStore = widgetStore
    self.eventHub = eventHub
  }

  var appEventSubscriptions: Set<String> { controller.appEventSubscriptions }

  /// Starts the time widget.
  func start() {
    controller.start()
  }

  /// Stops the time widget.
  func stop() {
    controller.stop()
  }
}
