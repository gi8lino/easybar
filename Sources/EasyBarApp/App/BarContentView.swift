import EasyBarShared
import SwiftUI

/// Root SwiftUI view of the EasyBar window.
struct BarContentView: View {
  /// Logger passed to child widget views.
  let logger: ProcessLogger
  /// Active immutable config snapshot store driving bar layout and styling.
  @EnvironmentObject private var configStore: ConfigSnapshotStore
  /// Default font used across the bar.
  private let globalBarFont = Font.custom("Symbols Nerd Font Mono", size: 13)

  /// Renders left, center, and right widget regions.
  var body: some View {
    let snapshot = configStore.snapshot

    HStack(spacing: 8) {
      WidgetBar(position: .left, logger: logger)

      Spacer(minLength: 0)

      WidgetBar(position: .center, logger: logger)

      Spacer(minLength: 0)

      WidgetBar(position: .right, logger: logger)
    }
    .font(globalBarFont)
    .padding(.horizontal, snapshot.bar.paddingX)
    .frame(
      maxWidth: .infinity,
      minHeight: snapshot.bar.height,
      maxHeight: snapshot.bar.height,
      alignment: .center
    )
    .background(Theme.barBackground(snapshot: snapshot))
    .overlay(alignment: .bottom) {
      if !snapshot.bar.borderHex.isFullyTransparentHexColor {
        Rectangle()
          .fill(Theme.barBorder(snapshot: snapshot))
          .frame(height: 1)
      }
    }
    .foregroundStyle(Theme.defaultTextColor(snapshot: snapshot))
    .ignoresSafeArea()
  }
}
