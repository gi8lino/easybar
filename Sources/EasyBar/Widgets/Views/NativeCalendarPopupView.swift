import SwiftUI

struct NativeCalendarPopupView: View {

    @ObservedObject private var store = NativeCalendarStore.shared

    var body: some View {
        let config = Config.shared.builtinCalendar

        VStack(alignment: .leading, spacing: config.popupSpacing) {
            emptyStateView(config: config)
            sectionsView(config: config)
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
    private func emptyStateView(config: Config.CalendarBuiltinConfig) -> some View {
        if store.sections.isEmpty {
            Text(config.emptyText)
                .foregroundStyle(color(config.popup.future.emptyColorHex))
        }
    }

    /// Builds the popup sections list when calendar data exists.
    @ViewBuilder
    private func sectionsView(config: Config.CalendarBuiltinConfig) -> some View {
        if !store.sections.isEmpty {
            ForEach(store.sections) { section in
                sectionView(section, config: config)
            }
        }
    }

    /// Builds one calendar popup section.
    private func sectionView(
        _ section: NativeCalendarPopupSection,
        config: Config.CalendarBuiltinConfig
    ) -> some View {
        let style = style(for: section.kind)

        return VStack(alignment: .leading, spacing: 4) {
            Text("\(section.title):")
                .foregroundStyle(color(style.titleColorHex))

            ForEach(section.items) { item in
                Text(itemLine(for: item))
                    .foregroundStyle(color(itemColor(for: item, style: style)))
                    .padding(.leading, config.popupItemIndent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func style(
        for kind: NativeCalendarPopupSectionKind
    ) -> Config.CalendarBuiltinConfig.PopupSectionStyle {
        let popup = Config.shared.builtinCalendar.popup

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

    private func itemLine(for item: NativeCalendarPopupItem) -> String {
        let config = Config.shared.builtinCalendar
        let prefix = config.popupShowCalendarName ? calendarNamePrefix(for: item) : ""

        if item.time.isEmpty {
            return prefix + item.title
        }

        return "\(item.time) \(prefix)\(item.title)"
    }

    /// Returns the effective text color for one popup item.
    private func itemColor(
        for item: NativeCalendarPopupItem,
        style: Config.CalendarBuiltinConfig.PopupSectionStyle
    ) -> String {
        if item.time.isEmpty {
            return style.emptyColorHex
        }

        let config = Config.shared.builtinCalendar

        if config.popupUseCalendarColors,
           let calendarColorHex = item.calendarColorHex,
           !calendarColorHex.isEmpty {
            return calendarColorHex
        }

        return style.itemColorHex
    }

    private func calendarNamePrefix(for item: NativeCalendarPopupItem) -> String {
        guard let calendarName = item.calendarName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !calendarName.isEmpty else {
            return ""
        }

        return "[\(calendarName)] "
    }

    private func color(_ hex: String) -> Color {
        Color(hex: hex)
    }
}
