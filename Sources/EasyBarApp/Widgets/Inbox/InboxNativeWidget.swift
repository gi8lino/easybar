import Combine
import Foundation

@MainActor
final class InboxNativeWidget: NativeWidget {
  let rootID = "builtin_inbox"
  let widgetStore: WidgetStore

  private let config: Config.InboxBuiltinConfig
  private let inboxStore: InboxStore
  private var cancellable: AnyCancellable?

  init(config: Config.InboxBuiltinConfig, widgetStore: WidgetStore, inboxStore: InboxStore) {
    self.config = config
    self.widgetStore = widgetStore
    self.inboxStore = inboxStore
  }

  func start() {
    inboxStore.updateConfiguration(config)
    cancellable = inboxStore.$presentedItems.sink { [weak self] items in
      self?.publish(items: items)
    }
  }

  func stop() {
    cancellable?.cancel()
    cancellable = nil
    clearNodes()
  }

  private func publish(items: [InboxPresentedItem]) {
    let unreadCount = items.lazy.filter(\.isUnread).count
    let hasUnread = unreadCount > 0
    let shouldShow = config.showWhenEmpty || !items.isEmpty
    var node = BuiltinNativeNodeFactory.makeItemNode(
      rootID: rootID,
      placement: config.placement,
      style: config.style,
      text: config.showUnreadCount && hasUnread ? String(unreadCount) : ""
    )
    let inactive = !hasUnread && config.useInactiveStyleWhenRead
    node.icon = inactive ? config.inactiveIcon : config.style.icon
    node.iconColor = inactive ? config.inactiveColorHex : config.iconColorHex
    node.labelColor = inactive ? config.inactiveColorHex : config.unreadCountColorHex
    node.visible = shouldShow
    applyNodes([node])
  }
}
