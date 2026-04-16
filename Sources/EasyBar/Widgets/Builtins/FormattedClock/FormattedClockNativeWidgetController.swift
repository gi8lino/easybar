import Foundation

/// Shared cache for format-driven date rendering across native widgets.
final class FormattedDateFormatterCache {

  private var formatters: [String: DateFormatter] = [:]

  func string(from date: Date, format: String) -> String {
    formatter(for: format).string(from: date)
  }

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

/// Shared controller for simple date/time native widgets that render one formatted timestamp.
@MainActor
final class FormattedClockNativeWidgetController {

  struct Snapshot {
    let placement: Config.BuiltinWidgetPlacement
    let style: Config.BuiltinWidgetStyle
    let format: String
  }

  let rootID: String

  private let snapshotProvider: () -> Snapshot
  private let eventObserver = EasyBarEventObserver()
  private let formatterCache = FormattedDateFormatterCache()

  init(rootID: String, snapshotProvider: @escaping () -> Snapshot) {
    self.rootID = rootID
    self.snapshotProvider = snapshotProvider
  }

  var appEventSubscriptions: Set<String> {
    [
      refreshEvent.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  func start() {
    NativeWidgetEventDriver.start(observer: eventObserver) { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }
      guard event == self.refreshEvent || event == .systemWoke else { return }
      self.publish()
    }

    publish()
  }

  func stop() {
    eventObserver.stop()
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  private var refreshEvent: AppEvent {
    FormattedClockRefreshPolicy.event(for: snapshotProvider().format)
  }

  private func publish() {
    let snapshot = snapshotProvider()

    let node = BuiltinNativeNodeFactory.makeItemNode(
      rootID: rootID,
      placement: snapshot.placement,
      style: snapshot.style,
      text: formatterCache.string(from: Date(), format: snapshot.format)
    )

    WidgetStore.shared.apply(root: rootID, nodes: [node])
  }
}

/// Resolves the lowest-cost refresh cadence that still keeps a formatted clock output current.
enum FormattedClockRefreshPolicy {

  static func event(for format: String) -> AppEvent {
    containsSecondPrecision(format) ? .secondTick : .minuteTick
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

      if !inQuotedLiteral && (character == "s" || character == "S") {
        return true
      }

      index = format.index(after: index)
    }

    return false
  }
}
