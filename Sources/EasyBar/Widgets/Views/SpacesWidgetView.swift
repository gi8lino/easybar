import SwiftUI

/// Renders all workspaces with their running applications.
struct SpacesWidgetView: View {

    @ObservedObject private var aeroSpaceService = AeroSpaceService.shared

    var body: some View {
        let config = Config.shared.builtinSpaces

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CGFloat(config.layout.spacing)) {
                ForEach(aeroSpaceService.spaces) { space in
                    spacePill(for: space, config: config)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            aeroSpaceService.focusWorkspace(space.name)
                        }
                }
            }
            .padding(.horizontal, CGFloat(config.layout.marginX))
            .padding(.vertical, CGFloat(config.layout.marginY))
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Builds one tappable space pill without using Button styling.
    @ViewBuilder
    private func spacePill(
        for space: SpaceItem,
        config: Config.SpacesBuiltinConfig
    ) -> some View {
        HStack(spacing: 6) {
            if shouldShowLabel(for: space, config: config) {
                Text(space.name)
                    .font(.system(
                        size: CGFloat(config.text.size),
                        weight: config.text.resolvedWeight
                    ))
                    .foregroundStyle(
                        space.isFocused ? Theme.spaceFocusedText : Theme.spaceInactiveText
                    )
            }

            if shouldShowIcons(for: space, config: config) {
                HStack(spacing: CGFloat(config.icons.spacing)) {
                    ForEach(visibleApps(for: space, config: config)) { app in
                        AppIconView(
                            app: app,
                            isFocusedApp: app.id == aeroSpaceService.focusedAppID
                        )
                    }

                    if hiddenAppCount(for: space, config: config) > 0 {
                        Text("+\(hiddenAppCount(for: space, config: config))")
                            .font(.system(
                                size: max(10, CGFloat(config.text.size) - 1),
                                weight: .medium
                            ))
                            .foregroundStyle(
                                space.isFocused ? Theme.spaceFocusedText : Theme.spaceInactiveText
                            )
                    }
                }
            }
        }
        .padding(.horizontal, resolvedPaddingX(for: space, config: config))
        .padding(.vertical, resolvedPaddingY(for: space, config: config))
        .background(
            space.isFocused
                ? Theme.spaceActiveBackground
                : Theme.spaceInactiveBackground
        )
        .overlay {
            RoundedRectangle(cornerRadius: resolvedCornerRadius(for: space, config: config))
                .stroke(
                    space.isFocused
                        ? Theme.spaceActiveBorder
                        : Theme.spaceInactiveBorder,
                    lineWidth: 1
                )
        }
        .clipShape(
            RoundedRectangle(cornerRadius: resolvedCornerRadius(for: space, config: config))
        )
        .scaleEffect(space.isFocused ? CGFloat(config.layout.focusedScale) : 1.0)
        .opacity(space.isFocused ? 1.0 : config.layout.inactiveOpacity)
    }

    /// Returns whether the space label should be shown.
    private func shouldShowLabel(
        for space: SpaceItem,
        config: Config.SpacesBuiltinConfig
    ) -> Bool {
        guard config.layout.showLabel else { return false }

        if config.layout.showOnlyFocusedLabel {
            return space.isFocused
        }

        return true
    }

    /// Returns whether app icons should be shown for one space.
    private func shouldShowIcons(
        for space: SpaceItem,
        config: Config.SpacesBuiltinConfig
    ) -> Bool {
        if !config.layout.showIcons {
            return false
        }

        if config.layout.collapseInactive && !space.isFocused {
            return false
        }

        return true
    }

    /// Returns the visible app icons for one space.
    private func visibleApps(
        for space: SpaceItem,
        config: Config.SpacesBuiltinConfig
    ) -> [SpaceApp] {
        let limit = max(0, config.layout.maxIcons)
        guard space.apps.count > limit else { return space.apps }
        return Array(space.apps.prefix(limit))
    }

    /// Returns the number of hidden apps for one space.
    private func hiddenAppCount(
        for space: SpaceItem,
        config: Config.SpacesBuiltinConfig
    ) -> Int {
        max(0, space.apps.count - visibleApps(for: space, config: config).count)
    }

    /// Returns horizontal pill padding for one space.
    private func resolvedPaddingX(
        for space: SpaceItem,
        config: Config.SpacesBuiltinConfig
    ) -> CGFloat {
        if config.layout.collapseInactive && !space.isFocused {
            return CGFloat(config.layout.collapsedPaddingX)
        }

        return CGFloat(config.layout.paddingX)
    }

    /// Returns vertical pill padding for one space.
    private func resolvedPaddingY(
        for space: SpaceItem,
        config: Config.SpacesBuiltinConfig
    ) -> CGFloat {
        if config.layout.collapseInactive && !space.isFocused {
            return CGFloat(config.layout.collapsedPaddingY)
        }

        return CGFloat(config.layout.paddingY)
    }

    /// Returns the corner radius for one space.
    private func resolvedCornerRadius(
        for space: SpaceItem,
        config: Config.SpacesBuiltinConfig
    ) -> CGFloat {
        space.isFocused
            ? CGFloat(config.layout.focusedCornerRadius)
            : CGFloat(config.layout.cornerRadius)
    }
}

/// Renders an individual app icon.
private struct AppIconView: View {

    let app: SpaceApp
    let isFocusedApp: Bool

    private var config: Config.SpacesBuiltinConfig {
        Config.shared.builtinSpaces
    }

    /// Returns the app icon size.
    private var resolvedSize: CGFloat {
        isFocusedApp
            ? CGFloat(config.icons.focusedAppSize)
            : CGFloat(config.icons.size)
    }

    /// Returns the app icon border width.
    private var resolvedBorderWidth: CGFloat {
        isFocusedApp
            ? CGFloat(config.icons.focusedAppBorderWidth)
            : CGFloat(config.icons.borderWidth)
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
            RoundedRectangle(cornerRadius: CGFloat(config.icons.cornerRadius))
        )
        .overlay {
            RoundedRectangle(cornerRadius: CGFloat(config.icons.cornerRadius))
                .stroke(
                    isFocusedApp ? Theme.spaceFocusedAppBorder : Color.clear,
                    lineWidth: resolvedBorderWidth
                )
        }
        .animation(.easeOut(duration: 0.12), value: isFocusedApp)
    }
}
