import SwiftUI

/// Root SwiftUI view of the EasyBar window.
struct BarRootView: View {

  var body: some View {
    HStack(spacing: 8) {
      WidgetBar(position: .left)

      Spacer(minLength: 0)

      WidgetBar(position: .center)

      Spacer(minLength: 0)

      WidgetBar(position: .right)
    }
    .padding(.horizontal, Config.shared.barPaddingX)
    .frame(
      maxWidth: .infinity,
      minHeight: Config.shared.barHeight,
      maxHeight: Config.shared.barHeight,
      alignment: .center
    )
    .background(Theme.barBackground)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Theme.barBorder)
        .frame(height: 1)
    }
    .foregroundStyle(Theme.defaultTextColor)
    .ignoresSafeArea()
  }
}
