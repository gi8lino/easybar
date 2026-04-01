import SwiftUI

/// Renders the popup for the native month-calendar widget.
struct NativeMonthCalendarPopupView: View {

  struct DayCell: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrentMonth: Bool
  }

  struct WeekRow: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let days: [DayCell]
  }

  struct DayIndicatorSegment: Identifiable {
    let id: String
    let colorHex: String
    let fraction: CGFloat
  }

  struct AgendaRow: Identifiable {
    enum Kind {
      case dayHeader(Date)
      case event(NativeMonthCalendarEvent)
    }

    let id: String
    let kind: Kind
  }

  @ObservedObject var store = NativeMonthCalendarStore.shared
  let config = Config.shared.builtinCalendar.month.popup
  let calendar = Calendar.current

  let composerPanel = MonthCalendarEventComposerPanelController()

  @State var visibleMonth = Self.startOfMonth(Date())
  @State var selectedStartDate = Date()
  @State var selectedEndDate = Date()

  @State var isDragSelecting = false
  @State var dragAnchorDate: Date?
  @State var dragDidCrossIntoAnotherDay = false
  @State var lastResolvedDragDate: Date?

  @State var monthGridFrame: CGRect = .zero
  @State var dayCellFrames: [Date: CGRect] = [:]

  /// Renders the month calendar popup.
  var body: some View {
    popupLayoutView
      .frame(width: popupWidth, alignment: .leading)
      .padding(.horizontal, CGFloat(config.paddingX))
      .padding(.vertical, CGFloat(config.paddingY))
      .background(color(config.backgroundColorHex))
      .overlay {
        RoundedRectangle(cornerRadius: popupCornerRadius, style: .continuous)
          .stroke(
            color(config.borderColorHex),
            lineWidth: max(CGFloat(config.borderWidth), 1)
          )
      }
      .clipShape(
        RoundedRectangle(cornerRadius: popupCornerRadius, style: .continuous)
      )
      .padding(.horizontal, CGFloat(config.marginX))
      .padding(.vertical, CGFloat(config.marginY))
      .onAppear {
        syncSelectionIntoVisibleMonth()
        MonthCalendarAgentClient.shared.refreshMonthSubscriptionIfNeeded(for: visibleMonth)
        logSelection("on_appear")
      }
      .onDisappear {
        composerPanel.close()
      }
      .onChange(of: visibleMonth) { _, newValue in
        MonthCalendarAgentClient.shared.refreshMonthSubscriptionIfNeeded(for: newValue)
      }
      .onChange(of: selectedStartDate) { _, _ in
        logSelection("selected_start_changed")
        logResolvedAppointments("selected_start_changed")
      }
      .onChange(of: selectedEndDate) { _, _ in
        logSelection("selected_end_changed")
        logResolvedAppointments("selected_end_changed")
      }
      .onChange(of: store.events.count) { _, count in
        Logger.debug("month calendar popup store events changed count=\(count)")
        logResolvedAppointments("store_events_changed")
      }
  }
}

// MARK: - Styling

extension NativeMonthCalendarPopupView {
  /// Returns the popup corner radius.
  var popupCornerRadius: CGFloat {
    max(CGFloat(config.cornerRadius), 12)
  }

  /// Returns the fixed popup width for the active layout.
  var popupWidth: CGFloat {
    switch config.layout {
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return 560
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return 260
    }
  }
}
