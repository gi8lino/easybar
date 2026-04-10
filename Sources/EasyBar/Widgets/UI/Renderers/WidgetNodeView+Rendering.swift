import SwiftUI

// MARK: - Top-Level Rendering

extension WidgetNodeView {
  /// Returns the rendered view for the current node kind.
  @ViewBuilder
  var renderedNodeView: some View {
    if node.kind.isRowLikeContainer {
      rowOrGroupView
    } else if node.kind.isCustomRenderedKind {
      customRenderedNodeView
    } else if node.kind.isDedicatedContainerKind {
      dedicatedContainerNodeView
    } else if node.kind.isInteractiveKind {
      interactiveNodeView
    } else if node.kind == .item {
      itemView
    } else {
      EmptyView()
    }
  }

  /// Returns the custom-rendered view for the current node kind.
  @ViewBuilder
  var customRenderedNodeView: some View {
    switch node.kind {
    case .spaces:
      SpacesWidgetView()
        .modifier(nodeStyle)
    default:
      EmptyView()
    }
  }

  /// Returns the dedicated container view for the current node kind.
  @ViewBuilder
  var dedicatedContainerNodeView: some View {
    switch node.kind {
    case .column:
      VStack(alignment: .leading, spacing: stackSpacing) {
        ForEach(children) { child in
          WidgetNodeView(node: child)
        }
      }
      .modifier(nodeStyle)
    case .popup:
      popupAnchor
    default:
      EmptyView()
    }
  }

  /// Returns the interactive view for the current node kind.
  @ViewBuilder
  var interactiveNodeView: some View {
    switch node.kind {
    case .slider:
      styledMouseContent(sliderView)
    case .progressSlider:
      styledMouseContent(progressSliderView)
    case .progress:
      styledMouseContent(progressView)
    case .sparkline:
      styledMouseContent(sparklineView)
    default:
      EmptyView()
    }
  }

  var rowOrGroupView: some View {
    Group {
      if node.isCalendarRoot {
        if calendarRootHasPopup {
          nativeCalendarAnchorView {
            childRow
          }
        } else {
          styledNodeSurface(childRow)
        }
      } else if hasPopupChildren {
        popupAnchorSurface(childRow)
      } else {
        styledNodeSurface(childRow)
      }
    }
  }

  var itemView: some View {
    if hasPopupChildren {
      return AnyView(popupItemSurface(itemContent))
    }

    return AnyView(styledNodeSurface(itemContent))
  }

  func nativeCalendarAnchorView<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .foregroundStyle(nodeColor)
      .modifier(nodeStyle)
      .onHover { hovering in handleAnchorHover(hovering) }
      .background {
        WidgetPopupAnchorView { anchor in
          popupPanel.updateAnchorView(anchor)
        }
      }
  }

  var popupAnchor: some View {
    let content = Group {
      if hasAnchorChildren {
        ForEach(anchorChildren) { child in
          WidgetNodeView(node: child)
        }
      } else {
        itemContent
      }
    }

    return popupAnchorSurface(content)
  }

  var popupContent: some View {
    VStack(alignment: .leading, spacing: stackSpacing) {
      ForEach(popupChildren) { child in
        WidgetNodeView(node: child)
      }
    }
    .fixedSize()
    .modifier(nodeStyle)
  }
}
