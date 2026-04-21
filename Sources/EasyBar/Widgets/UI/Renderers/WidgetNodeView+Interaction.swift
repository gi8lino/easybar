import SwiftUI

// MARK: - Interaction

extension WidgetNodeView {
  func styledNodeSurface<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .overlay(nodeMouseOverlay)
    )
  }

  func styledMouseContent<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .onHover { hovering in
          guard node.isMouseHoverInteractive else { return }
          emitNodeHoverEvent(hovering)
        }
        .simultaneousGesture(
          TapGesture().onEnded {
            guard node.isMouseClickInteractive else { return }
            emitNodeClickEvent()
          }
        )
        .overlay(scrollOverlay)
    )
  }

  func popupAnchorSurface<Content: View>(_ content: Content) -> some View {
    let base = AnyView(content.foregroundStyle(nodeColor))
    let surfaced = popupAnchorInteractiveSurface(base)

    return AnyView(
      surfaced
        .onHover { hovering in handleAnchorHover(hovering) }
        .background {
          WidgetPopupAnchorView { anchor in
            popupPanel.updateAnchorView(anchor)
          }
        }
    )
  }

  func popupItemSurface<Content: View>(_ content: Content) -> some View {
    content
      .modifier(nodeStyle)
      .contentShape(Rectangle())
      .overlay(popupAnchorMouseOverlay)
      .onHover { hovering in handleAnchorHover(hovering) }
      .background {
        WidgetPopupAnchorView { anchor in
          popupPanel.updateAnchorView(anchor)
        }
      }
  }

  func nodeEventSurface(tracksHover: Bool = true) -> some View {
    GeometryReader { proxy in
      WidgetMouseView(
        widgetID: node.root,
        targetWidgetID: node.id,
        tracksHover: tracksHover,
        emitsMouseDown: node.isMouseDownInteractive,
        emitsMouseUp: node.isMouseUpInteractive,
        emitsMouseClick: node.isMouseClickInteractive,
        emitsMouseScroll: node.isMouseScrollInteractive
      )
      .frame(width: proxy.size.width, height: proxy.size.height)
      .contentShape(Rectangle())
    }
  }

  @ViewBuilder
  var scrollOverlay: some View {
    if node.isMouseScrollInteractive {
      nodeEventSurface(tracksHover: false)
    }
  }

  @ViewBuilder
  var nodeMouseOverlay: some View {
    if node.isMouseHoverInteractive || node.isMouseDownInteractive || node.isMouseUpInteractive
      || node.isMouseClickInteractive || node.isMouseScrollInteractive
    {
      nodeEventSurface(tracksHover: node.isMouseHoverInteractive)
    }
  }

  func popupAnchorInteractiveSurface<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .overlay(popupAnchorMouseOverlay)
    )
  }

  @ViewBuilder
  var popupAnchorMouseOverlay: some View {
    if node.isMouseDownInteractive || node.isMouseUpInteractive || node.isMouseClickInteractive
      || node.isMouseScrollInteractive
    {
      nodeEventSurface(tracksHover: false)
    }
  }

  func emitNodeHoverEvent(_ hovering: Bool) {
    let event: WidgetEvent = hovering ? .mouseEntered : .mouseExited

    Task {
      await EventHub.shared.emitWidgetEvent(
        event,
        widgetID: node.root,
        targetWidgetID: node.id
      )
    }
  }

  func emitNodeClickEvent() {
    Task {
      await EventHub.shared.emitWidgetEvent(
        .mouseClicked,
        widgetID: node.root,
        targetWidgetID: node.id,
        button: .left
      )
    }
  }
}
