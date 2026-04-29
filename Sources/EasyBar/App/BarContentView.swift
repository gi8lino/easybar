import EasyBarShared
import SwiftUI

/// Root SwiftUI view of the EasyBar window.
struct BarContentView: View {
  let logger: ProcessLogger
  @ObservedObject private var config = Config.shared
  private let globalBarFont = Font.custom("Symbols Nerd Font Mono", size: 13)

  var body: some View {
    HStack(spacing: 8) {
      WidgetBar(position: .left, logger: logger)

      Spacer(minLength: 0)

      WidgetBar(position: .center, logger: logger)

      Spacer(minLength: 0)

      WidgetBar(position: .right, logger: logger)
    }
    .font(globalBarFont)
    .padding(.horizontal, config.barPaddingX)
    .frame(
      maxWidth: .infinity,
      minHeight: config.barHeight,
      maxHeight: config.barHeight,
      alignment: .center
    )
    .background(Theme.barBackground)
    .overlay(alignment: .bottom) {
      if config.barShowsBorder {
        Rectangle()
          .fill(Theme.barBorder)
          .frame(height: 1)
      }
    }
    .foregroundStyle(Theme.defaultTextColor)
    .ignoresSafeArea()
  }
}
