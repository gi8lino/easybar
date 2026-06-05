import EasyBarShared
import Foundation

public struct CalendarBuiltinConfig {
  public struct Filters {
    public var includedCalendarNames: [String]
    public var excludedCalendarNames: [String]
    public var includedCalendarIDs: [String]
    public var excludedCalendarIDs: [String]
    public var includedCalendarSourceIDs: [String]
    public var excludedCalendarSourceIDs: [String]

    public init(
      includedCalendarNames: [String],
      excludedCalendarNames: [String],
      includedCalendarIDs: [String],
      excludedCalendarIDs: [String],
      includedCalendarSourceIDs: [String],
      excludedCalendarSourceIDs: [String]
    ) {
      self.includedCalendarNames = includedCalendarNames
      self.excludedCalendarNames = excludedCalendarNames
      self.includedCalendarIDs = includedCalendarIDs
      self.excludedCalendarIDs = excludedCalendarIDs
      self.includedCalendarSourceIDs = includedCalendarSourceIDs
      self.excludedCalendarSourceIDs = excludedCalendarSourceIDs
    }
  }

  public struct Appointments {
    public var itemIndent: Double
    public var eventTextColorHex: String
    public var emptyTextColorHex: String
    public var secondaryTextColorHex: String
    public var travelTextColorHex: String
    public var emptyText: String
    public var showCalendarName: Bool
    public var showAllDayLabel: Bool
    public var showHolidayAllDayLabel: Bool
    public var allDayLabel: String
    public var showLocation: Bool
    public var showTravelTime: Bool
    public var showEndTime: Bool
    public var travelIcon: String
    public var travelIconColorHex: String?
    public var showAlertIcon: Bool
    public var alertIcon: String
    public var alertIconColorHex: String?

    public init(
      itemIndent: Double,
      eventTextColorHex: String,
      emptyTextColorHex: String,
      secondaryTextColorHex: String,
      travelTextColorHex: String,
      emptyText: String,
      showCalendarName: Bool,
      showAllDayLabel: Bool,
      showHolidayAllDayLabel: Bool,
      allDayLabel: String,
      showLocation: Bool,
      showTravelTime: Bool,
      showEndTime: Bool,
      travelIcon: String,
      travelIconColorHex: String?,
      showAlertIcon: Bool,
      alertIcon: String,
      alertIconColorHex: String?
    ) {
      self.itemIndent = itemIndent
      self.eventTextColorHex = eventTextColorHex
      self.emptyTextColorHex = emptyTextColorHex
      self.secondaryTextColorHex = secondaryTextColorHex
      self.travelTextColorHex = travelTextColorHex
      self.emptyText = emptyText
      self.showCalendarName = showCalendarName
      self.showAllDayLabel = showAllDayLabel
      self.showHolidayAllDayLabel = showHolidayAllDayLabel
      self.allDayLabel = allDayLabel
      self.showLocation = showLocation
      self.showTravelTime = showTravelTime
      self.showEndTime = showEndTime
      self.travelIcon = travelIcon
      self.travelIconColorHex = travelIconColorHex
      self.showAlertIcon = showAlertIcon
      self.alertIcon = alertIcon
      self.alertIconColorHex = alertIconColorHex
    }
  }

  public struct Birthdays {
    public var showBirthdays: Bool
    public var birthdaysShowAge: Bool
    public var birthdayIcon: String
    public var birthdayIconColorHex: String?

    public init(
      showBirthdays: Bool,
      birthdaysShowAge: Bool,
      birthdayIcon: String,
      birthdayIconColorHex: String?
    ) {
      self.showBirthdays = showBirthdays
      self.birthdaysShowAge = birthdaysShowAge
      self.birthdayIcon = birthdayIcon
      self.birthdayIconColorHex = birthdayIconColorHex
    }
  }

  public struct Anchor {
    public var itemFormat: String
    public var layout: CalendarAnchorLayout
    public var topFormat: String
    public var bottomFormat: String
    public var lineSpacing: Double
    public var topTextColorHex: String?
    public var bottomTextColorHex: String?

    public init(
      itemFormat: String,
      layout: CalendarAnchorLayout,
      topFormat: String,
      bottomFormat: String,
      lineSpacing: Double,
      topTextColorHex: String?,
      bottomTextColorHex: String?
    ) {
      self.itemFormat = itemFormat
      self.layout = layout
      self.topFormat = topFormat
      self.bottomFormat = bottomFormat
      self.lineSpacing = lineSpacing
      self.topTextColorHex = topTextColorHex
      self.bottomTextColorHex = bottomTextColorHex
    }
  }

  public var placement: CalendarWidgetPlacement
  public var style: CalendarWidgetStyle
  public var popupMode: CalendarPopupMode
  public var anchor: Anchor
  public var filters: Filters
  public var appointments: Appointments
  public var birthdays: Birthdays
  public var composer: Composer
  public var upcoming: Upcoming
  public var month: Month

  public init(
    placement: CalendarWidgetPlacement,
    style: CalendarWidgetStyle,
    popupMode: CalendarPopupMode,
    anchor: Anchor,
    filters: Filters,
    appointments: Appointments,
    birthdays: Birthdays,
    composer: Composer,
    upcoming: Upcoming,
    month: Month
  ) {
    self.placement = placement
    self.style = style
    self.popupMode = popupMode
    self.anchor = anchor
    self.filters = filters
    self.appointments = appointments
    self.birthdays = birthdays
    self.composer = composer
    self.upcoming = upcoming
    self.month = month
  }

  public var enabled: Bool {
    get { placement.enabled }
    set { placement.enabled = newValue }
  }

  public var position: WidgetPosition {
    get { placement.position }
    set { placement.position = newValue }
  }

  public var order: Int {
    get { placement.order }
    set { placement.order = newValue }
  }
}
