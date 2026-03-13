import SwiftUI

/// Root SwiftUI view of the EasyBar window.
struct BarRootView: View {

    @ObservedObject private var aeroSpaceService: AeroSpaceService

    /// Creates the root bar view.
    init(aeroSpaceService: AeroSpaceService) {
        self.aeroSpaceService = aeroSpaceService
    }

    var body: some View {
        HStack(spacing: 8) {
            WidgetBar(position: "left")

            SpacesWidget(aeroSpaceService: aeroSpaceService)

            WidgetBar(position: "center")

            Spacer()

            WidgetBar(position: "right")
        }
        .padding(.horizontal, Config.shared.barPadding)
        .frame(height: Config.shared.barHeight)
        .background(Theme.barBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.barBorder)
                .frame(height: 1)
        }
        .foregroundStyle(Theme.textColor)
    }
}
