import SwiftUI

// MARK: - Interaction

extension WidgetNodeView {
  func styledContainerSurface<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .background(nodeMouseOverlay)
    )
  }

  func styledNodeSurface<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .overlay(nodeMouseOverlay)
    )
  }

  /// Styles one native interactive control surface without attaching an extra tap gesture.
  ///
  /// Native controls such as `Slider` already manage their own mouse tracking and drag
  /// lifecycle. Adding an extra `TapGesture` wrapper can interfere with dragging.
  func styledControlContent<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .onHover { hovering in
          guard node.isMouseHoverInteractive else { return }
          emitNodeHoverEvent(hovering)
        }
        .overlay(scrollOverlay)
    )
  }

  func styledMouseContent<Content: View>(_ content: Content) -> some View {
    let base = AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .onHover { hovering in
          guard node.isMouseHoverInteractive else { return }
          emitNodeHoverEvent(hovering)
        }
        .overlay(scrollOverlay)
    )

    guard node.isMouseClickInteractive else {
      return base
    }

    return AnyView(
      base.simultaneousGesture(
        TapGesture().onEnded {
          emitNodeClickEvent()
        }
      )
    )
  }

  func popupAnchorSurface<Content: View>(_ content: Content) -> some View {
    let base = AnyView(content.foregroundStyle(nodeColor))
    let surfaced = popupAnchorInteractiveSurface(base)

    return AnyView(
      surfaced
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
        emitsMouseHover: node.isMouseHoverInteractive,
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
    if nodeCanPresentPopup || node.isMouseHoverInteractive || node.isMouseDownInteractive
      || node.isMouseUpInteractive || node.isMouseClickInteractive || node.isMouseScrollInteractive
    {
      GeometryReader { proxy in
        WidgetMouseView(
          widgetID: node.root,
          targetWidgetID: node.id,
          tracksHover: true,
          emitsMouseHover: node.isMouseHoverInteractive,
          emitsMouseDown: node.isMouseDownInteractive,
          emitsMouseUp: node.isMouseUpInteractive,
          emitsMouseClick: node.isMouseClickInteractive,
          emitsMouseScroll: node.isMouseScrollInteractive,
          onHoverChanged: handleAnchorHover
        )
        .frame(width: proxy.size.width, height: proxy.size.height)
        .contentShape(Rectangle())
      }
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
