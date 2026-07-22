import AppKit
import SwiftUI

struct InboxPopupView: View {
  @ObservedObject var store: InboxStore
  let eventHub: EventHub
  @EnvironmentObject private var configStore: ConfigSnapshotStore

  var body: some View {
    let config = configStore.snapshot.builtins.inbox

    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Inbox").font(.headline).foregroundStyle(color(config.popupTitleColorHex))
        Spacer()
        if store.unreadCount > 0 {
          Button("Mark all read") { store.markAllRead() }
            .buttonStyle(.plain)
            .foregroundStyle(color(config.popupMutedColorHex))
        }
        if !store.presentedItems.isEmpty {
          Button("Dismiss all") { store.dismissAll() }
            .buttonStyle(.plain)
            .foregroundStyle(color(config.popupMutedColorHex))
        }
        if config.showSourceActions, !store.sourceConfigurations.isEmpty {
          Menu {
            ForEach(store.sourceConfigurations, id: \.source) { configuration in
              Menu(configuration.source) {
                ForEach(configuration.actions) { action in
                  Button(action.title) {
                    emitAction(
                      .inboxContextAction,
                      actionID: action.id,
                      source: configuration.source,
                      targetWidgetID: "builtin_inbox"
                    )
                  }
                }
              }
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
          .menuStyle(.borderlessButton)
          .fixedSize()
          .foregroundStyle(color(config.popupMutedColorHex))
          .help("Inbox actions")
        }
      }

      if store.presentedItems.isEmpty {
        Text("No messages")
          .foregroundStyle(color(config.popupMutedColorHex))
          .padding(.vertical, 8)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(Array(store.groups().enumerated()), id: \.offset) { _, group in
              if let title = group.title {
                sourceGroupHeader(
                  title: title,
                  presentation: group.sourcePresentation,
                  config: config
                )
              }
              ForEach(group.items) { item in
                itemView(item, config: config)
              }
            }
          }
          .id(config.groupBy)
        }
        .frame(maxHeight: CGFloat(config.popupMaxHeight))
      }
    }
    .frame(width: CGFloat(config.popupWidth), alignment: .leading)
    .padding(12)
    .background(color(config.popupBackgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(
          color(config.popupBorderColorHex),
          lineWidth: 1
        )
    }
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func itemView(
    _ presented: InboxPresentedItem,
    config: Config.InboxBuiltinConfig
  ) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      if config.groupBy != .source {
        let source = presented.item.source
        HStack(spacing: 4) {
          if let icon = source?.icon, !icon.isEmpty {
            InboxSourceIconView(
              value: icon,
              color: color(source?.color ?? config.popupMutedColorHex)
            )
          }
          Text(source?.name?.isEmpty == false ? source?.name ?? presented.source : presented.source)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color(source?.color ?? config.popupMutedColorHex))
        .onTapGesture { store.markRead(presented) }
      }

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Button {
          store.toggleRead(presented)
        } label: {
          Circle()
            .fill(presented.isUnread ? severityColor(presented.item.resolvedSeverity) : .clear)
            .overlay {
              Circle().stroke(color(config.popupMutedColorHex), lineWidth: presented.isUnread ? 0 : 1)
            }
            .frame(width: 7, height: 7)
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(presented.isUnread ? "Mark as read" : "Mark as unread")
        Text(presented.item.title)
          .font(.system(size: 13, weight: presented.isUnread ? .semibold : .regular))
          .foregroundStyle(color(config.popupTitleColorHex))
          .onTapGesture { store.markRead(presented) }
        Spacer(minLength: 4)
      }

      if let body = presented.item.body, !body.isEmpty {
        bodyText(body, format: presented.item.resolvedFormat)
          .font(.system(size: 12))
          .foregroundStyle(
            color(config.popupTextColorHex)
          )
          .onTapGesture { store.markRead(presented) }
      }

      if let actions = presented.item.actions, !actions.isEmpty {
        HStack(spacing: 10) {
          ForEach(actions) { action in
            Button(action.title) {
              store.markRead(presented)
              emitAction(
                .inboxAction,
                actionID: action.id,
                source: presented.source,
                targetWidgetID: presented.item.id
              )
            }
            .buttonStyle(.plain)
            .foregroundStyle(color(config.popupActionColorHex))
          }
        }
        .font(.caption)
      }

      if let value = presented.item.url, let url = URL(string: value) {
        Button("Open") {
          store.markRead(presented)
          NSWorkspace.shared.open(url)
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(color(config.popupActionColorHex))
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color(config.popupItemBackgroundColorHex))
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .contentShape(Rectangle())
    .contextMenu {
      Button(presented.isUnread ? "Mark as read" : "Mark as unread") {
        store.toggleRead(presented)
      }
      if presented.item.isDismissible {
        Divider()
        Button("Dismiss") { store.dismiss(presented) }
      }
    }
  }

  private func sourceGroupHeader(
    title: String,
    presentation: InboxSourcePresentation?,
    config: Config.InboxBuiltinConfig
  ) -> some View {
    HStack(spacing: 5) {
      if config.groupBy == .source, let icon = presentation?.icon, !icon.isEmpty {
        InboxSourceIconView(
          value: icon,
          color: color(presentation?.color ?? config.popupMutedColorHex)
        )
      }
      Text(title)
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(color(presentation?.color ?? config.popupMutedColorHex))
  }

  @ViewBuilder
  private func bodyText(_ body: String, format: InboxBodyFormat) -> some View {
    if format == .markdown,
      let attributed = try? AttributedString(
        markdown: body,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
      )
    {
      Text(attributed)
    } else {
      Text(body)
    }
  }

  private func emitAction(
    _ event: WidgetEvent,
    actionID: String,
    source: String,
    targetWidgetID: String
  ) {
    Task {
      await eventHub.emitWidgetEvent(
        event,
        widgetID: "builtin_inbox",
        targetWidgetID: targetWidgetID,
        source: source,
        actionID: actionID
      )
    }
  }

  private func color(_ value: String?) -> Color {
    Color(hex: value ?? configStore.snapshot.theme.colors.text, snapshot: configStore.snapshot)
  }

  private func severityColor(_ severity: InboxSeverity) -> Color {
    let config = configStore.snapshot.builtins.inbox
    switch severity {
    case .info: return color(config.infoColorHex)
    case .success: return color(config.successColorHex)
    case .warning: return color(config.warningColorHex)
    case .error: return color(config.errorColorHex)
    }
  }
}

private struct InboxSourceIconView: View {
  let value: String
  let color: Color

  private var imageSource: WidgetImageSource? {
    value.hasPrefix("/") ? .path(value) : nil
  }

  var body: some View {
    if let imageSource {
      WidgetImageView(source: imageSource, size: 12, tint: color)
    } else {
      Text(value)
    }
  }
}
