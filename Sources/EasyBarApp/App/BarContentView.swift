import EasyBarShared
import SwiftUI

/// Root SwiftUI view of the EasyBar window.
struct BarContentView: View {
  let logger: ProcessLogger
  @EnvironmentObject private var configStore: ConfigSnapshotStore
  @EnvironmentObject private var widgetStore: WidgetStore
  private let globalBarFont = Font.custom("Symbols Nerd Font Mono", size: 13)

  var body: some View {
    let snapshot = configStore.snapshot

    HStack(spacing: 8) {
      widgetBar(position: .left)

      Spacer(minLength: 0)

      widgetBar(position: .center)

      Spacer(minLength: 0)

      widgetBar(position: .right)
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

  private func widgetBar(position: WidgetPosition) -> some View {
    HStack(spacing: 4) {
      ForEach(widgetStore.topLevelNodes(for: position)) { node in
        WidgetNodeView(node: node, logger: logger)
      }
    }
  }
}
