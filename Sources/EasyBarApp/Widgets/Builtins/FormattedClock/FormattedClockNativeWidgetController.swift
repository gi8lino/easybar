import Foundation

/// Shared cache for format-driven date rendering across native widgets.
final class FormattedDateFormatterCache {

  private var formatters: [String: DateFormatter] = [:]

  /// Formats one date with a cached formatter for the given format.
  func string(from date: Date, format: String) -> String {
    return formatter(for: format).string(from: date)
  }

  /// Returns a cached formatter for the given date format.
  private func formatter(for format: String) -> DateFormatter {
    if let formatter = formatters[format] {
      return formatter
    }

    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.calendar = .autoupdatingCurrent
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = format
    formatters[format] = formatter
    return formatter
  }
}

/// Native widget that renders one formatted timestamp.
@MainActor
final class FormattedClockNativeWidget: NativeWidget {

  let rootID: String
  let widgetStore: WidgetStore

  private let placement: Config.BuiltinWidgetPlacement
  private let style: Config.BuiltinWidgetStyle
  private let format: String
  private let eventObserver: EasyBarEventObserver
  private let formatterCache = FormattedDateFormatterCache()

  init(
    rootID: String,
    widgetStore: WidgetStore,
    eventHub: EventHub,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    format: String
  ) {
    self.rootID = rootID
    self.widgetStore = widgetStore
    self.eventObserver = EasyBarEventObserver(eventHub: eventHub)
    self.placement = placement
    self.style = style
    self.format = format
  }

  var appEventSubscriptions: Set<String> {
    [
      refreshEvent.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  /// Starts observing clock refresh events.
  func start() {
    eventObserver.start(eventNames: appEventSubscriptions) { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }
      guard event == self.refreshEvent || event == .systemWoke else { return }
      self.publish()
    }

    publish()
  }

  /// Stops observing events and clears the rendered node.
  func stop() {
    eventObserver.stop()
    clearNodes()
  }

  private var refreshEvent: AppEvent {
    return FormattedClockRefreshPolicy.event(for: format)
  }

  /// Publishes the current formatted timestamp.
  private func publish() {
    let node = BuiltinNativeNodeFactory.makeItemNode(
      rootID: rootID,
      placement: placement,
      style: style,
      text: formatterCache.string(from: Date(), format: format)
    )

    applyNodes([node])
  }
}

/// Resolves the lowest-cost refresh cadence that still keeps a formatted clock output current.
enum FormattedClockRefreshPolicy {

  /// Returns the refresh event required by the given date format.
  static func event(for format: String) -> AppEvent {
    return containsSecondPrecision(format) ? .secondTick : .minuteTick
  }

  /// Detects real second-based fields while ignoring quoted literals in the date format string.
  private static func containsSecondPrecision(_ format: String) -> Bool {
    var index = format.startIndex
    var inQuotedLiteral = false

    while index < format.endIndex {
      let character = format[index]

      if character == "'" {
        let nextIndex = format.index(after: index)
        if nextIndex < format.endIndex, format[nextIndex] == "'" {
          index = format.index(after: nextIndex)
          continue
        }

        inQuotedLiteral.toggle()
        index = nextIndex
        continue
      }

      if isSecondPrecisionToken(character, inQuotedLiteral: inQuotedLiteral) {
        return true
      }

      index = format.index(after: index)
    }

    return false
  }

  /// Returns whether the character represents an unquoted second-precision token.
  private static func isSecondPrecisionToken(
    _ character: Character,
    inQuotedLiteral: Bool
  ) -> Bool {
    return !inQuotedLiteral && (character == "s" || character == "S")
  }
}
