import SwiftUI

/// Renders all workspaces with their running applications.
struct SpacesWidgetView: View {

    @ObservedObject private var aeroSpaceService = AeroSpaceService.shared

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
                            RoundedRectangle(cornerRadius: resolvedCornerRadius(for: space))
                                .stroke(
                                    space.isFocused
                                    ? Theme.spaceActiveBorder
                                    : Theme.spaceInactiveBorder,
                                    lineWidth: 1
                                )
                        }
                        .clipShape(
                            RoundedRectangle(cornerRadius: resolvedCornerRadius(for: space))
                        )
                        .scaleEffect(space.isFocused ? Config.shared.spaceFocusedScale : 1.0)
                        .opacity(space.isFocused ? 1.0 : Config.shared.spaceInactiveOpacity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Config.shared.spaceMarginX)
            .padding(.vertical, Config.shared.spaceMarginY)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Returns whether the space label should be shown.
    private func shouldShowLabel(for space: SpaceItem) -> Bool {
        guard Config.shared.showSpaceLabel else { return false }

        if Config.shared.showOnlyFocusedLabel {
            return space.isFocused
        }

        return true
    }

    /// Returns whether app icons should be shown for one space.
    private func shouldShowIcons(for space: SpaceItem) -> Bool {
        if !Config.shared.showSpaceIcons {
            return false
        }

        if Config.shared.collapseInactiveSpaces && !space.isFocused {
            return false
        }

        return true
    }

    /// Returns the visible app icons for one space.
    private func visibleApps(for space: SpaceItem) -> [SpaceApp] {
        let limit = max(0, Config.shared.maxIconsPerSpace)
        guard space.apps.count > limit else { return space.apps }
        return Array(space.apps.prefix(limit))
    }

    /// Returns the number of hidden apps for one space.
    private func hiddenAppCount(for space: SpaceItem) -> Int {
        max(0, space.apps.count - visibleApps(for: space).count)
    }

    /// Returns horizontal pill padding for one space.
    private func resolvedPaddingX(for space: SpaceItem) -> CGFloat {
        if Config.shared.collapseInactiveSpaces && !space.isFocused {
            return Config.shared.collapsedSpacePaddingX
        }

        return Config.shared.spacePaddingX
    }

    /// Returns vertical pill padding for one space.
    private func resolvedPaddingY(for space: SpaceItem) -> CGFloat {
        if Config.shared.collapseInactiveSpaces && !space.isFocused {
            return Config.shared.collapsedSpacePaddingY
        }

        return Config.shared.spacePaddingY
    }

    /// Returns the corner radius for one space.
    private func resolvedCornerRadius(for space: SpaceItem) -> CGFloat {
        space.isFocused
            ? Config.shared.spaceFocusedCornerRadius
            : Config.shared.spaceCornerRadius
    }
}

/// Renders an individual app icon.
private struct AppIconView: View {

    let app: SpaceApp
    let isFocusedApp: Bool

    /// Returns the app icon size.
    private var resolvedSize: CGFloat {
        isFocusedApp ? Config.shared.focusedAppIconSize : Config.shared.iconSize
    }

    /// Returns the app icon border width.
    private var resolvedBorderWidth: CGFloat {
        isFocusedApp ? Config.shared.focusedAppIconBorderWidth : Config.shared.iconBorderWidth
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
                    isFocusedApp ? Theme.spaceFocusedAppBorder : Color.clear,
                    lineWidth: resolvedBorderWidth
                )
        }
        .animation(.easeOut(duration: 0.12), value: isFocusedApp)
    }
}
