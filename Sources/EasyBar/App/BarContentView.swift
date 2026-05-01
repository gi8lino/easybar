import EasyBarShared
import SwiftUI

/// Root SwiftUI view of the EasyBar window.
struct BarContentView: View {
  /// Logger passed to child widget views.
  let logger: ProcessLogger
  /// Shared config driving bar layout and styling.
  @ObservedObject private var config = Config.shared
  /// Default font used across the bar.
  private let globalBarFont = Font.custom("Symbols Nerd Font Mono", size: 13)

  /// Renders left, center, and right widget regions.
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
