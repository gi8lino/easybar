import SwiftUI

/// Renders all workspaces with their running applications.
struct SpacesWidget: View {

    @ObservedObject private var aeroSpaceService: AeroSpaceService

    /// Creates the widget.
    init(aeroSpaceService: AeroSpaceService) {
        self.aeroSpaceService = aeroSpaceService
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Config.shared.spaceSpacing) {
                ForEach(aeroSpaceService.spaces) { space in
                    Button {
                        aeroSpaceService.focusWorkspace(space.name)
                    } label: {
                        HStack(spacing: 6) {
                            if shouldShowLabel(for: space) {
                                Text(space.name)
                                    .font(.system(
                                        size: Config.shared.spaceTextSize,
                                        weight: Config.shared.resolvedSpaceTextWeight
                                    ))
                                    .foregroundStyle(
                                        space.isFocused ? Theme.spaceFocusedText : Theme.spaceInactiveText
                                    )
                            }

                            if shouldShowIcons(for: space) {
                                HStack(spacing: Config.shared.iconSpacing) {
                                    ForEach(visibleApps(for: space)) { app in
                                        AppIconView(
                                            app: app,
                                            isFocusedApp: app.id == aeroSpaceService.focusedAppID
                                        )
                                    }

                                    if hiddenAppCount(for: space) > 0 {
                                        Text("+\(hiddenAppCount(for: space))")
                                            .font(.system(
                                                size: max(10, Config.shared.spaceTextSize - 1),
                                                weight: .medium
                                            ))
                                            .foregroundStyle(
                                                space.isFocused ? Theme.spaceFocusedText : Theme.spaceInactiveText
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, resolvedPaddingX(for: space))
                        .padding(.vertical, resolvedPaddingY(for: space))
                        .background(
                            space.isFocused
                            ? Theme.spaceActiveBackground
                            : Theme.spaceInactiveBackground
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: Config.shared.spaceCornerRadius)
                                .stroke(
                                    space.isFocused
                                    ? Theme.spaceActiveBorder
                                    : Theme.spaceInactiveBorder,
                                    lineWidth: 1
                                )
                        }
                        .clipShape(
                            RoundedRectangle(cornerRadius: Config.shared.spaceCornerRadius)
                        )
                        .scaleEffect(space.isFocused ? Config.shared.spaceFocusedScale : 1.0)
                        .opacity(space.isFocused ? 1.0 : Config.shared.spaceInactiveOpacity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Returns whether the workspace number should be shown.
    private func shouldShowLabel(for space: SpaceItem) -> Bool {
        guard Config.shared.showSpaceNumber else { return false }
        if Config.shared.showOnlyFocusedLabel {
            return space.isFocused
        }
        return true
    }

    /// Returns whether icons should be shown for the workspace.
    private func shouldShowIcons(for space: SpaceItem) -> Bool {
        if !Config.shared.showSpaceIcons {
            return false
        }

        if Config.shared.collapseInactiveSpaces && !space.isFocused {
            return false
        }

        return true
    }

    /// Returns visible apps for a space based on the configured icon limit.
    private func visibleApps(for space: SpaceItem) -> [SpaceApp] {
        let limit = max(0, Config.shared.maxIconsPerSpace)
        guard space.apps.count > limit else { return space.apps }
        return Array(space.apps.prefix(limit))
    }

    /// Returns the number of hidden apps for a space.
    private func hiddenAppCount(for space: SpaceItem) -> Int {
        max(0, space.apps.count - visibleApps(for: space).count)
    }

    /// Returns horizontal padding based on collapsed state.
    private func resolvedPaddingX(for space: SpaceItem) -> CGFloat {
        if Config.shared.collapseInactiveSpaces && !space.isFocused {
            return Config.shared.collapsedSpacePaddingX
        }
        return Config.shared.spacePaddingX
    }

    /// Returns vertical padding based on collapsed state.
    private func resolvedPaddingY(for space: SpaceItem) -> CGFloat {
        if Config.shared.collapseInactiveSpaces && !space.isFocused {
            return Config.shared.collapsedSpacePaddingY
        }
        return Config.shared.spacePaddingY
    }
}

/// Renders an individual app icon.
private struct AppIconView: View {

    let app: SpaceApp
    let isFocusedApp: Bool

    private var resolvedSize: CGFloat {
        isFocusedApp ? Config.shared.focusedIconSize : Config.shared.iconSize
    }

    private var resolvedBorderWidth: CGFloat {
        isFocusedApp ? Config.shared.focusedIconBorderWidth : Config.shared.iconBorderWidth
    }

    var body: some View {
        Group {
            if let icon = app.icon() {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Text(String(app.name.prefix(1)).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.10))
            }
        }
        .frame(width: resolvedSize, height: resolvedSize)
        .clipShape(
            RoundedRectangle(cornerRadius: Config.shared.iconCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Config.shared.iconCornerRadius)
                .stroke(
                    isFocusedApp ? Theme.focusedAppBorder : Color.clear,
                    lineWidth: resolvedBorderWidth
                )
        }
        .animation(.easeOut(duration: 0.12), value: isFocusedApp)
    }
}
