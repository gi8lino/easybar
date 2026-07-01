import SwiftUI

/// Popup content variants that need native SwiftUI adapters instead of node children.
enum NativePopupContentKind: Equatable {
  case none
  case calendarUpcoming
  case calendarMonth
  case genericNodePopup
}

/// Resolves the popup content for one widget node.
@MainActor
struct WidgetPopupContentResolver {
  let node: WidgetNodeState
  let hasPopupChildren: Bool
  let configStore: ConfigSnapshotStore
  let widgetStore: WidgetStore

  /// Returns whether the node currently has popup content that can be presented.
  var canPresentPopup: Bool {
    return contentKind != .none
  }

  /// Returns whether the resolved popup should use the native popup anchor adapter.
  var usesNativePopupAnchor: Bool {
    switch contentKind {
    case .calendarUpcoming, .calendarMonth:
      return true
    case .none, .genericNodePopup:
      return false
    }
  }

  /// Builds the popup panel content for the resolved content kind.
  func makeContent<RegularContent: View, HoverBackground: View>(
    regularContent: RegularContent,
    hoverBackground: HoverBackground
  ) -> AnyView {
    switch contentKind {
    case .none:
      return AnyView(EmptyView())

    case .calendarUpcoming:
      return AnyView(
        NativeUpcomingCalendarPopupView()
          .environmentObject(configStore)
          .background(hoverBackground)
      )

    case .calendarMonth:
      return AnyView(
        NativeMonthCalendarPopupView()
          .environmentObject(configStore)
          .background(hoverBackground)
      )

    case .genericNodePopup:
      return AnyView(
        regularContent
          .environmentObject(configStore)
          .environmentObject(widgetStore)
          .background(hoverBackground)
      )
    }
  }

  /// Returns the popup content kind for the current node and config snapshot.
  private var contentKind: NativePopupContentKind {
    if node.isCalendarRoot {
      return calendarContentKind
    }

    guard node.kind == .popup || hasPopupChildren else {
      return .none
    }

    return .genericNodePopup
  }

  /// Maps the configured calendar popup mode into a native popup content kind.
  private var calendarContentKind: NativePopupContentKind {
    switch configStore.snapshot.builtins.calendar.popupMode {
    case .none:
      return .none
    case .upcoming:
      return .calendarUpcoming
    case .month:
      return .calendarMonth
    }
  }
}
