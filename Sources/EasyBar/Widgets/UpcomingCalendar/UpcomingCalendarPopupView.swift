import SwiftUI

struct NativeUpcomingCalendarPopupView: View {

  @ObservedObject private var store = NativeUpcomingCalendarStore.shared
  private let upcoming = Config.shared.builtinCalendar.upcoming
  private let popup = Config.shared.builtinCalendar.upcoming.popup

  /// Renders the native upcoming-calendar popup content.
  var body: some View {
    VStack(alignment: .leading, spacing: popup.spacing) {
      emptyStateView
      sectionsView
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, popup.paddingX)
    .padding(.vertical, popup.paddingY)
    .background(color(popup.backgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: popup.cornerRadius)
        .stroke(
          color(popup.borderColorHex),
          lineWidth: popup.borderWidth
        )
    }
    .clipShape(
      RoundedRectangle(cornerRadius: popup.cornerRadius)
    )
    .padding(.horizontal, popup.marginX)
    .padding(.vertical, popup.marginY)
    .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
  }

  /// Builds the empty popup state when no sections are available.
  @ViewBuilder
  private var emptyStateView: some View {
    if store.sections.isEmpty {
      Text(upcoming.events.emptyText)
        .foregroundStyle(color(popup.future.emptyColorHex))
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
          .padding(.leading, popup.itemIndent)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Returns the popup style for one section kind.
  private func style(
    for kind: NativeUpcomingCalendarPopupSectionKind
  ) -> Config.CalendarBuiltinConfig.Upcoming.PopupSectionStyle {
    switch kind {
    case .birthdays:
      return popup.birthdays
    case .today:
      return popup.today
    case .tomorrow:
      return popup.tomorrow
    case .future:
      return popup.future
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
    style: Config.CalendarBuiltinConfig.Upcoming.PopupSectionStyle
  ) -> String {
    if item.time.isEmpty {
      return style.emptyColorHex
    }

    if popup.useCalendarColors,
      let calendarColorHex = item.calendarColorHex,
      !calendarColorHex.isEmpty
    {
      return calendarColorHex
    }

    return style.itemColorHex
  }

  /// Returns the optional calendar-name prefix.
  private func calendarNamePrefix(for item: NativeUpcomingCalendarPopupItem) -> String {
    guard popup.showCalendarName else { return "" }
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
