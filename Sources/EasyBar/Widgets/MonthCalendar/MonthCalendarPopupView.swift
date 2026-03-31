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

  @State var visibleMonth = Self.startOfMonth(Date())
  @State var selectedStartDate = Date()
  @State var selectedEndDate = Date()

  @State var isDragSelecting = false
  @State var dragAnchorDate: Date?

  /// Renders the month calendar popup.
  var body: some View {
    popupLayoutView
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, CGFloat(config.paddingX))
      .padding(.vertical, CGFloat(config.paddingY))
      .background(color(config.backgroundColorHex))
      .overlay {
        RoundedRectangle(cornerRadius: CGFloat(config.cornerRadius))
          .stroke(
            color(config.borderColorHex),
            lineWidth: CGFloat(config.borderWidth)
          )
      }
      .clipShape(
        RoundedRectangle(cornerRadius: CGFloat(config.cornerRadius))
      )
      .padding(.horizontal, CGFloat(config.marginX))
      .padding(.vertical, CGFloat(config.marginY))
      .frame(minWidth: minimumPopupWidth, maxWidth: .infinity, alignment: .leading)
      .onAppear {
        syncSelectionIntoVisibleMonth()
        MonthCalendarAgentClient.shared.refreshMonthSubscriptionIfNeeded(for: visibleMonth)
        logSelection("on_appear")
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
