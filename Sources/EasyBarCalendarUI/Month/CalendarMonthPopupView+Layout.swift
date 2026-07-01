import SwiftUI

extension CalendarMonthPopupView {
  /// Builds the configured popup layout.
  @ViewBuilder
  var popupLayoutView: some View {
    if isHorizontalLayout {
      HStack(alignment: .top, spacing: horizontalContentSpacing) {
        orderedPopupSectionViews
      }
    } else {
      VStack(alignment: .leading, spacing: verticalContentSpacing) {
        orderedPopupSectionViews
      }
    }
  }

  /// Builds the popup sections in the configured order.
  @ViewBuilder
  var orderedPopupSectionViews: some View {
    if isCalendarFirstLayout {
      calendarSectionView
      agendaContainerView
    } else {
      agendaContainerView
      calendarSectionView
    }
  }

  /// Returns the spacing used in horizontal layouts.
  var horizontalContentSpacing: CGFloat {
    return CGFloat(config.spacing)
  }

  /// Returns the spacing used in vertical layouts.
  var verticalContentSpacing: CGFloat {
    return CGFloat(config.spacing + 6)
  }

  /// Returns the minimum popup width for the current layout.
  var minimumPopupWidth: CGFloat {
    switch config.layout {
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return horizontalPopupMinimumWidth
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return verticalPopupMinimumWidth
    }
  }

  /// Returns the fixed width used by the calendar pane.
  var calendarContainerWidth: CGFloat {
    return 260
  }

  /// Returns the minimum width reserved for the agenda in horizontal layouts.
  var horizontalAgendaMinimumWidth: CGFloat {
    return 220
  }

  /// Returns the minimum width reserved for the agenda in vertical layouts.
  var verticalAgendaMinimumWidth: CGFloat {
    return 220
  }

  /// Returns the minimum popup width used by horizontal layouts.
  var horizontalPopupMinimumWidth: CGFloat {
    return calendarContainerWidth + horizontalAgendaMinimumWidth + max(horizontalContentSpacing, 0)
  }

  /// Returns the minimum popup width used by vertical layouts.
  var verticalPopupMinimumWidth: CGFloat {
    return max(calendarContainerWidth, verticalAgendaMinimumWidth)
  }

  /// Builds the full calendar section with grid and today helper.
  var calendarSectionView: some View {
    return calendarContainerView
  }

  /// Builds the calendar container.
  var calendarContainerView: some View {
    VStack(alignment: .leading, spacing: CGFloat(config.spacing)) {
      headerView
      weekdayHeaderView
      monthGridView
    }
    .frame(
      minWidth: calendarContainerWidth,
      maxWidth: calendarContainerWidth,
      alignment: .topLeading
    )
  }

  /// Builds the year-picker overlay shown above the popup content.
  var yearPickerOverlayView: some View {
    VStack {
      MonthYearPickerPopover(
        currentYear: visibleYear,
        pageStartYear: $yearPickerPageStart,
        onSelectYear: selectYear(_:),
        onClose: { isYearPickerPresented = false },
        headerColor: color(config.headerTextColorHex),
        backgroundColor: color(config.backgroundColorHex),
        borderColor: color(config.borderColorHex),
        currentYearTextColor: color(config.headerTextColorHex),
        currentYearBackgroundColor: color(config.todayCellBackgroundColorHex),
        currentYearBorderColor: color(config.todayCellBorderColorHex)
      )
      .padding(.top, 40)
      .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 6)

      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .zIndex(2)
  }

  /// Builds the agenda container.
  var agendaContainerView: some View {
    VStack(alignment: .leading, spacing: CGFloat(config.spacing)) {
      appointmentsContainerView
    }
    .frame(
      minWidth: isHorizontalLayout ? horizontalAgendaMinimumWidth : nil,
      maxWidth: .infinity,
      alignment: .topLeading
    )
  }

  /// Returns whether the current popup layout is horizontal.
  var isHorizontalLayout: Bool {
    switch config.layout {
    case .calendarAppointmentsHorizontal, .appointmentsCalendarHorizontal:
      return true
    case .calendarAppointmentsVertical, .appointmentsCalendarVertical:
      return false
    }
  }

  /// Returns whether the current popup layout is vertical.
  var isVerticalLayout: Bool {
    return !isHorizontalLayout
  }

  /// Returns whether the calendar section appears before the agenda section.
  var isCalendarFirstLayout: Bool {
    switch config.layout {
    case .calendarAppointmentsHorizontal, .calendarAppointmentsVertical:
      return true
    case .appointmentsCalendarHorizontal, .appointmentsCalendarVertical:
      return false
    }
  }

  /// Returns the minimum height of the appointments area.
  var appointmentsMinHeight: CGFloat {
    return CGFloat(min(config.appointmentsMinHeight, config.appointmentsMaxHeight))
  }

  /// Returns the maximum height of the appointments area.
  var appointmentsMaxHeight: CGFloat {
    return CGFloat(max(config.appointmentsMinHeight, config.appointmentsMaxHeight))
  }

  /// Returns the fixed height used by the scrollable appointments viewport.
  var appointmentsScrollableHeight: CGFloat {
    return appointmentsMaxHeight
  }
}
