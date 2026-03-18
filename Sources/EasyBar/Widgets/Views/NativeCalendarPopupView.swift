import SwiftUI

struct NativeCalendarPopupView: View {

    @ObservedObject private var store = NativeCalendarStore.shared

    var body: some View {
        let config = Config.shared.builtinCalendar

        VStack(alignment: .leading, spacing: config.popupSpacing) {
            if store.sections.isEmpty {
                Text(config.emptyText)
                    .foregroundStyle(color(config.popup.future.emptyColorHex))
            } else {
                ForEach(store.sections) { section in
                    let style = style(for: section.kind)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(section.title):")
                            .foregroundStyle(color(style.titleColorHex))

                        ForEach(section.items) { item in
                            Text(itemLine(for: item))
                                .foregroundStyle(
                                    color(item.time.isEmpty ? style.emptyColorHex : style.itemColorHex)
                                )
                                .padding(.leading, config.popupItemIndent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
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
        if item.time.isEmpty {
            return item.title
        }

        return "\(item.time) \(item.title)"
    }

    private func color(_ hex: String) -> Color {
        Color(hex: hex)
    }
}
