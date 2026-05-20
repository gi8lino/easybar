import EasyBarCalendarPresentation
import EasyBarShared
import SwiftUI

/// Renders the reusable month-calendar popup.
public struct CalendarMonthPopupView<Store: CalendarMonthPopupStore>: View {

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

  typealias AgendaRow = CalendarAgendaBuilder.Entry

  @ObservedObject var store: Store
  let logger: ProcessLogger
  let config: CalendarMonthPopupConfig
  let appointmentsStyle: CalendarAppointmentsStyle
  let birthdays: CalendarBirthdayStyle
  let emptyText: String
  let onVisibleMonthChanged: (Date) -> Void
  let onCreateEvent: (Date, @escaping () -> Void) -> Void
  let onEditEvent: (CalendarAgentEvent, @escaping () -> Void) -> Void
  let onRefreshRequested: () -> Void
  let calendar = Calendar.current

  public init(
    store: Store,
    logger: ProcessLogger,
    config: CalendarMonthPopupConfig,
    appointmentsStyle: CalendarAppointmentsStyle,
    birthdays: CalendarBirthdayStyle,
    emptyText: String,
    onVisibleMonthChanged: @escaping (Date) -> Void,
    onCreateEvent: @escaping (Date, @escaping () -> Void) -> Void,
    onEditEvent: @escaping (CalendarAgentEvent, @escaping () -> Void) -> Void,
    onRefreshRequested: @escaping () -> Void
  ) {
    self.store = store
    self.logger = logger
    self.config = config
    self.appointmentsStyle = appointmentsStyle
    self.birthdays = birthdays
    self.emptyText = emptyText
    self.onVisibleMonthChanged = onVisibleMonthChanged
    self.onCreateEvent = onCreateEvent
    self.onEditEvent = onEditEvent
    self.onRefreshRequested = onRefreshRequested
  }

  @State var visibleMonth = Self.startOfMonth(Date())
  @State var selectedStartDate = Date()
  @State var selectedEndDate = Date()

  @State var isDragSelecting = false
  @State var dragAnchorDate: Date?
  @State var dragDidCrossIntoAnotherDay = false
  @State var lastResolvedDragDate: Date?

  @State var monthGridFrame: CGRect = .zero
  @State var dayCellFrames: [Date: CGRect] = [:]
  @State var isYearPickerPresented = false
  @State var yearPickerPageStart = 0
  @State var shouldAutoSelectVisibleMonthEvent = false

  /// Renders the month calendar popup.
  public var body: some View {
    ZStack {
      popupLayoutView

      if isYearPickerPresented {
        Color.black
          .opacity(0.001)
          .contentShape(Rectangle())
          .onTapGesture {
            isYearPickerPresented = false
          }

        yearPickerOverlayView
      }
    }
    .frame(width: popupWidth, alignment: .leading)
    .padding(.horizontal, CGFloat(config.paddingX))
    .padding(.vertical, CGFloat(config.paddingY))
    .background(color(config.backgroundColorHex))
    .overlay {
      RoundedRectangle(cornerRadius: popupCornerRadius, style: .continuous)
        .stroke(
          color(config.borderColorHex),
          lineWidth: CalendarUIPrimitives.borderLineWidth(config.borderWidth)
        )
    }
    .clipShape(
      RoundedRectangle(cornerRadius: popupCornerRadius, style: .continuous)
    )
    .padding(.horizontal, CGFloat(config.marginX))
    .padding(.vertical, CGFloat(config.marginY))
    .onAppear {
      syncSelectionIntoVisibleMonth()
      onVisibleMonthChanged(visibleMonth)
      logSelection("on_appear")
    }
    .onChange(of: visibleMonth) { _, newValue in
      onVisibleMonthChanged(newValue)
    }
    .onChange(of: selectedStartDate) { _, _ in
      logSelection("selected_start_changed")
      logResolvedAppointments("selected_start_changed")
    }
    .onChange(of: selectedEndDate) { _, _ in
      logSelection("selected_end_changed")
      logResolvedAppointments("selected_end_changed")
    }
    .onChange(of: store.snapshot?.generatedAt) { _, generatedAt in
      logger.debug(
        "month calendar popup snapshot changed",
        .field("generated_at", "\(generatedAt?.description ?? "nil")"),
      )
      resolveVisibleMonthAutoSelection()
      logResolvedAppointments("snapshot_changed")
    }
  }
}

// MARK: - Styling

extension CalendarMonthPopupView {
  /// Returns the popup corner radius.
  var popupCornerRadius: CGFloat {
    return max(CGFloat(config.cornerRadius), 12)
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
