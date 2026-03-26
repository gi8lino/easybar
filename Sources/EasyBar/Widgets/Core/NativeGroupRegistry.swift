import Foundation

/// Publishes config-defined native groups into the shared widget store.
final class NativeGroupRegistry {

    static let shared = NativeGroupRegistry()

    private var publishedRootIDs: [String] = []

    private init() {}

    /// Rebuilds all native groups from the current config.
    func reload() {
        clear()

        for group in Config.shared.builtinGroups {
            WidgetStore.shared.apply(root: group.id, nodes: [makeNode(group)])
            publishedRootIDs.append(group.id)
        }
    }

    /// Clears all previously published native groups.
    func clear() {
        for rootID in publishedRootIDs {
            WidgetStore.shared.apply(root: rootID, nodes: [])
        }

        publishedRootIDs.removeAll()
    }

    /// Builds one native group root node.
    private func makeNode(_ group: Config.BuiltinGroupConfig) -> WidgetNodeState {
        WidgetNodeState(
            id: group.id,
            root: group.id,
            kind: .group,
            parent: group.placement.groupID,
            position: group.placement.position,
            order: group.placement.order,
            icon: "",
            text: "",
            color: group.style.textColorHex,
            iconColor: nil,
            labelColor: nil,
            visible: true,
            role: nil,
            receivesMouseHover: nil,
            receivesMouseClick: nil,
            receivesMouseScroll: nil,
            imagePath: nil,
            imageSize: nil,
            imageCornerRadius: nil,
            fontSize: nil,
            iconFontSize: nil,
            labelFontSize: nil,
            value: nil,
            min: nil,
            max: nil,
            step: nil,
            values: nil,
            lineWidth: nil,
            paddingX: group.style.paddingX,
            paddingY: group.style.paddingY,
            paddingLeft: nil,
            paddingRight: nil,
            paddingTop: nil,
            paddingBottom: nil,
            spacing: group.style.spacing,
            backgroundColor: group.style.backgroundColorHex,
            borderColor: group.style.borderColorHex,
            borderWidth: group.style.borderWidth,
            cornerRadius: group.style.cornerRadius,
            opacity: group.style.opacity,
            width: nil,
            height: nil,
            yOffset: nil
        )
    }
}
