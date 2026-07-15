import Foundation

/// Native date widget backed by the shared formatted-clock controller.
@MainActor
final class DateNativeWidget: NativeWidget {

  let rootID = "builtin_date"
  let widgetStore: WidgetStore
  private let config: Config.DateBuiltinConfig
  private let eventHub: EventHub
  private lazy var controller = FormattedClockNativeWidgetController(
    rootID: rootID,
    widgetStore: widgetStore,
    eventHub: eventHub,
    snapshot:
      .init(
        placement: config.placement,
        style: config.style,
        format: config.format
      )
  )

  /// Creates the native date widget from an immutable config section.
  init(config: Config.DateBuiltinConfig, widgetStore: WidgetStore, eventHub: EventHub) {
    self.config = config
    self.widgetStore = widgetStore
    self.eventHub = eventHub
  }

  var appEventSubscriptions: Set<String> { controller.appEventSubscriptions }

  /// Starts the date widget.
  func start() {
    controller.start()
  }

  /// Stops the date widget.
  func stop() {
    controller.stop()
  }
}
