import SwiftUI

struct NativeCalendarPopupView: View {

    @ObservedObject private var store = NativeCalendarStore.shared

    var body: some View {
        let config = Config.shared.builtinCalendar

        VStack(alignment: .leading, spacing: config.popupSpacing) {
            if store.sections.isEmpty {
                Text(config.emptyText)
                    .foregroundStyle(color(config.popupEmptyColorHex))
            } else {
                ForEach(store.sections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(section.title):")
                            .foregroundStyle(color(config.popupSectionTitleColorHex))

                        ForEach(section.items) { item in
                            Text("\(item.time) \(item.title)")
                                .foregroundStyle(color(config.popupItemColorHex))
                                .padding(.leading, config.popupItemIndent)
                        }
                    }
                }
            }
        }
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
        .frame(minWidth: 220, alignment: .leading)
    }

    private func color(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

