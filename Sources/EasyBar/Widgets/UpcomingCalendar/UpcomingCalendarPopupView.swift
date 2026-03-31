import SwiftUI

struct NativeUpcomingCalendarPopupView: View {

  @ObservedObject private var store = NativeUpcomingCalendarStore.shared
  private let config = Config.shared.builtinCalendar

  /// Renders the native upcoming-calendar popup content.
  var body: some View {
    VStack(alignment: .leading, spacing: config.popupSpacing) {
      emptyStateView
      sectionsView
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, config.popupPaddingX)
    .padding(.vertical, config.popupPaddingY)
    .background(color(config.popupBackgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: config.popupCornerRadius)
        .stroke(
          color(config.popupBorderColorHex),
          lineWidth: config.popupBorderWidth
        )
    }
    .clipShape(
      RoundedRectangle(cornerRadius: config.popupCornerRadius)
    )
    .padding(.horizontal, config.popupMarginX)
    .padding(.vertical, config.popupMarginY)
    .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
  }

  /// Builds the empty popup state when no sections are available.
  @ViewBuilder
  private var emptyStateView: some View {
    if store.sections.isEmpty {
      Text(config.emptyText)
        .foregroundStyle(color(config.popup.future.emptyColorHex))
    }
  }

  /// Builds the popup sections list when calendar data exists.
  @ViewBuilder
  private var sectionsView: some View {
    if !store.sections.isEmpty {
      ForEach(store.sections) { section in
        sectionView(section)
      }
    }
  }

  /// Builds one calendar popup section.
  private func sectionView(_ section: NativeUpcomingCalendarPopupSection) -> some View {
    let style = style(for: section.kind)

    return VStack(alignment: .leading, spacing: 4) {
      Text("\(section.title):")
        .foregroundStyle(color(style.titleColorHex))

      ForEach(section.items) { item in
        Text(itemLine(for: item))
          .foregroundStyle(color(itemTextColor(for: item, style: style)))
          .padding(.leading, config.popupItemIndent)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Returns the popup style for one section kind.
  private func style(
    for kind: NativeUpcomingCalendarPopupSectionKind
  ) -> Config.CalendarBuiltinConfig.PopupSectionStyle {
    switch kind {
    case .birthdays:
      return config.popup.birthdays
    case .today:
      return config.popup.today
    case .tomorrow:
      return config.popup.tomorrow
    case .future:
      return config.popup.future
    }
  }

  /// Builds the rendered line for one popup item.
  private func itemLine(for item: NativeUpcomingCalendarPopupItem) -> String {
    let prefix = calendarNamePrefix(for: item)

    if item.time.isEmpty {
      return prefix + item.title
    }

    return "\(item.time) \(prefix)\(item.title)"
  }

  /// Returns the effective text color for one popup item.
  private func itemTextColor(
    for item: NativeUpcomingCalendarPopupItem,
    style: Config.CalendarBuiltinConfig.PopupSectionStyle
  ) -> String {
    if item.time.isEmpty {
      return style.emptyColorHex
    }

    if config.popupUseCalendarColors,
      let calendarColorHex = item.calendarColorHex,
      !calendarColorHex.isEmpty
    {
      return calendarColorHex
    }

    return style.itemColorHex
  }

  /// Returns the optional calendar-name prefix.
  private func calendarNamePrefix(for item: NativeUpcomingCalendarPopupItem) -> String {
    guard config.popupShowCalendarName else { return "" }
    guard let calendarName = item.calendarName?.trimmingCharacters(in: .whitespacesAndNewlines),
      !calendarName.isEmpty
    else {
      return ""
    }

    return "[\(calendarName)] "
  }

  /// Converts one hex string into SwiftUI color.
  private func color(_ hex: String) -> Color {
    Color(hex: hex)
  }
}
