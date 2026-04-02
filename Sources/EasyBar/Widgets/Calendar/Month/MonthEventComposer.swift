import AppKit
import Combine
import EasyBarShared
import Foundation

@MainActor
final class MonthCalendarEventComposer: ObservableObject {

  struct CalendarOption: Identifiable, Equatable {
    let id: String
    let title: String

    static func == (lhs: CalendarOption, rhs: CalendarOption) -> Bool {
      lhs.id == rhs.id
    }
  }

  struct AlertRow: Identifiable, Equatable {
    let id: UUID
    var option: AlertOption

    init(id: UUID = UUID(), option: AlertOption) {
      self.id = id
      self.option = option
    }
  }

  enum Mode {
    case create
    case edit(eventIdentifier: String)
  }

  enum AlertOption: String, CaseIterable, Identifiable {
    case none
    case atTime = "at_time"
    case fiveMinutes = "5_minutes"
    case tenMinutes = "10_minutes"
    case fifteenMinutes = "15_minutes"
    case thirtyMinutes = "30_minutes"
    case oneHour = "1_hour"
    case oneDay = "1_day"

    var id: String { rawValue }

    var fallbackTitle: String {
      switch self {
      case .none:
        return "None"
      case .atTime:
        return "At time of event"
      case .fiveMinutes:
        return "5 minutes before"
      case .tenMinutes:
        return "10 minutes before"
      case .fifteenMinutes:
        return "15 minutes before"
      case .thirtyMinutes:
        return "30 minutes before"
      case .oneHour:
        return "1 hour before"
      case .oneDay:
        return "1 day before"
      }
    }

    /// Returns the lead time in seconds before the event.
    var leadTimeSeconds: TimeInterval? {
      switch self {
      case .none:
        return nil
      case .atTime:
        return 0
      case .fiveMinutes:
        return 300
      case .tenMinutes:
        return 600
      case .fifteenMinutes:
        return 900
      case .thirtyMinutes:
        return 1800
      case .oneHour:
        return 3600
      case .oneDay:
        return 86_400
      }
    }
  }

  enum TravelTimeOption: String, CaseIterable, Identifiable {
    case none
    case fiveMinutes = "5_minutes"
    case tenMinutes = "10_minutes"
    case fifteenMinutes = "15_minutes"
    case twentyMinutes = "20_minutes"
    case thirtyMinutes = "30_minutes"
    case fortyFiveMinutes = "45_minutes"
    case oneHour = "1_hour"
    case ninetyMinutes = "90_minutes"
    case twoHours = "2_hours"

    var id: String { rawValue }

    var fallbackTitle: String {
      switch self {
      case .none:
        return "None"
      case .fiveMinutes:
        return "5 minutes"
      case .tenMinutes:
        return "10 minutes"
      case .fifteenMinutes:
        return "15 minutes"
      case .twentyMinutes:
        return "20 minutes"
      case .thirtyMinutes:
        return "30 minutes"
      case .fortyFiveMinutes:
        return "45 minutes"
      case .oneHour:
        return "1 hour"
      case .ninetyMinutes:
        return "1.5 hours"
      case .twoHours:
        return "2 hours"
      }
    }

    var seconds: TimeInterval? {
      switch self {
      case .none:
        return nil
      case .fiveMinutes:
        return 300
      case .tenMinutes:
        return 600
      case .fifteenMinutes:
        return 900
      case .twentyMinutes:
        return 1200
      case .thirtyMinutes:
        return 1800
      case .fortyFiveMinutes:
        return 2700
      case .oneHour:
        return 3600
      case .ninetyMinutes:
        return 5400
      case .twoHours:
        return 7200
      }
    }
  }

  @Published private(set) var calendars: [CalendarOption] = []
  @Published private(set) var accessGranted = false
  @Published private(set) var isSaving = false
  @Published private(set) var mode: Mode = .create

  @Published var title = ""
  @Published var startDate = Date()
  @Published var endDate = Date()
  @Published var startTime = Date()
  @Published var endTime = Date()
  @Published var isAllDay = false
  @Published var selectedCalendarID = ""
  @Published var location = ""
  @Published var alertRows: [AlertRow] = [.init(option: .tenMinutes)]
  @Published var travelTime: TravelTimeOption = .none

  @Published var errorMessage: String?
  @Published var infoMessage: String?

  private let calendar = Calendar.current
  private let popupConfig = Config.shared.builtinCalendar.month.popup

  private var cancellables: Set<AnyCancellable> = []
  private var preferredCalendarName: String?

  init() {
    NativeMonthCalendarStore.shared.$snapshot
      .receive(on: DispatchQueue.main)
      .sink { [weak self] snapshot in
        self?.applySnapshot(snapshot)
      }
      .store(in: &cancellables)

    applySnapshot(NativeMonthCalendarStore.shared.snapshot)
  }

  /// Returns whether the composer currently has the minimum data to save.
  var canSave: Bool {
    accessGranted
      && !isSaving
      && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !selectedCalendarID.isEmpty
  }

  /// Returns whether the current event can be removed.
  var canDelete: Bool {
    if case .edit = mode {
      return accessGranted && !isSaving
    }

    return false
  }

  /// Returns the current panel title.
  var panelTitle: String {
    switch mode {
    case .create:
      return popupConfig.composerCreateTitle
    case .edit:
      return popupConfig.composerEditTitle
    }
  }

  /// Returns the current primary action title.
  var saveButtonTitle: String {
    switch mode {
    case .create:
      return isSaving ? "\(popupConfig.composerSaveLabel)..." : popupConfig.composerSaveLabel
    case .edit:
      return isSaving ? "\(popupConfig.composerUpdateLabel)..." : popupConfig.composerUpdateLabel
    }
  }

  /// Prepares the composer for the given date using agent-backed state.
  func prepare(defaultDate: Date) {
    mode = .create
    preferredCalendarName = normalizedOptionalText(popupConfig.composerDefaultCalendarName)

    let normalizedDate = calendar.startOfDay(for: defaultDate)
    reset(using: normalizedDate)
    applySnapshot(NativeMonthCalendarStore.shared.snapshot)
    MonthCalendarAgentClient.shared.refresh()
  }

  /// Prepares the composer for editing one existing event using agent-backed state.
  func prepare(event: NativeMonthCalendarEvent) {
    let normalizedStartDate = calendar.startOfDay(for: event.startDate)
    let normalizedEndReference =
      event.isAllDay
      ? calendar.date(byAdding: .day, value: -1, to: event.endDate) ?? event.startDate
      : event.endDate
    let normalizedEndDate = calendar.startOfDay(for: normalizedEndReference)

    reset(using: normalizedStartDate)

    guard let eventIdentifier = resolvedEventIdentifier(from: event) else {
      errorMessage = "This appointment cannot be edited."
      return
    }

    mode = .edit(eventIdentifier: eventIdentifier)
    title = event.title
    startDate = normalizedStartDate
    endDate = normalizedEndDate
    startTime = event.startDate
    endTime = event.endDate
    isAllDay = event.isAllDay
    location = event.location ?? ""
    alertRows = resolvedAlertRows(from: event.alertOffsetsSeconds)
    travelTime = resolvedTravelTimeOption(from: event.travelTimeSeconds)
    preferredCalendarName = normalizedOptionalText(event.calendarName)

    applySnapshot(NativeMonthCalendarStore.shared.snapshot)
    MonthCalendarAgentClient.shared.refresh()
  }

  /// Resets the form fields to a clean state using one selected date.
  func reset(using defaultDate: Date) {
    let normalizedDate = calendar.startOfDay(for: defaultDate)

    title = ""
    startDate = normalizedDate
    endDate = normalizedDate
    startTime = defaultStartTime(on: normalizedDate)
    endTime = defaultEndTime(on: normalizedDate)
    isAllDay = false
    location = ""
    alertRows = resolvedDefaultAlertRows()
    travelTime = resolvedDefaultTravelTime()
    errorMessage = nil
    infoMessage = nil
    isSaving = false
  }

  /// Saves the current appointment through the calendar agent.
  func save(onSuccess: @escaping () -> Void) {
    clearMessages()

    guard accessGranted else {
      errorMessage = "Calendar access is not available."
      return
    }

    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else {
      errorMessage = "Please enter a title."
      return
    }

    guard let selectedCalendar = selectedCalendarOption else {
      errorMessage = "Please select a calendar."
      return
    }

    let resolvedDates = resolvedEventDates()
    guard resolvedDates.start < resolvedDates.end else {
      errorMessage = "The end time must be after the start time."
      return
    }

    isSaving = true

    switch mode {
    case .create:
      let draft = CalendarAgentCreateEvent(
        title: trimmedTitle,
        startDate: resolvedDates.start,
        endDate: resolvedDates.end,
        isAllDay: isAllDay,
        calendarName: selectedCalendar.title,
        location: normalizedOptionalText(location),
        alertOffsetsSeconds: resolvedAlertOffsetsSeconds(),
        travelTimeSeconds: travelTime.seconds
      )

      MonthCalendarAgentClient.shared.createEvent(draft) { [weak self] success, message in
        guard let self else { return }
        self.handleMutationResult(
          success: success,
          failureMessage: message,
          successMessage: "Appointment created.",
          onSuccess: onSuccess
        )
      }

    case .edit(let eventIdentifier):
      let draft = CalendarAgentUpdateEvent(
        eventIdentifier: eventIdentifier,
        title: trimmedTitle,
        startDate: resolvedDates.start,
        endDate: resolvedDates.end,
        isAllDay: isAllDay,
        calendarName: selectedCalendar.title,
        location: normalizedOptionalText(location),
        alertOffsetsSeconds: resolvedAlertOffsetsSeconds(),
        travelTimeSeconds: travelTime.seconds
      )

      MonthCalendarAgentClient.shared.updateEvent(draft) { [weak self] success, message in
        guard let self else { return }
        self.handleMutationResult(
          success: success,
          failureMessage: message,
          successMessage: "Appointment updated.",
          onSuccess: onSuccess
        )
      }
    }
  }

  /// Deletes the current appointment through the calendar agent.
  func delete(onSuccess: @escaping () -> Void) {
    clearMessages()

    guard accessGranted else {
      errorMessage = "Calendar access is not available."
      return
    }

    guard case .edit(let eventIdentifier) = mode else {
      errorMessage = "Nothing to delete."
      return
    }

    isSaving = true

    let draft = CalendarAgentDeleteEvent(eventIdentifier: eventIdentifier)

    MonthCalendarAgentClient.shared.deleteEvent(draft) { [weak self] success, message in
      guard let self else { return }
      self.handleMutationResult(
        success: success,
        failureMessage: message,
        successMessage: "Appointment removed.",
        onSuccess: onSuccess
      )
    }
  }

  /// Opens the official Calendar.app.
  func openCalendarApp() {
    guard
      let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal")
    else {
      return
    }

    NSWorkspace.shared.open(appURL)
  }
}

// MARK: - Agent Snapshot

extension MonthCalendarEventComposer {
  /// Applies one agent snapshot to composer state.
  private func applySnapshot(_ snapshot: EasyBarShared.CalendarAgentSnapshot?) {
    guard let snapshot else {
      accessGranted = false
      calendars = []
      selectedCalendarID = ""
      return
    }

    accessGranted = snapshot.accessGranted

    calendars = snapshot.writableCalendars.map { calendar in
      CalendarOption(
        id: calendar.id,
        title: calendar.title
      )
    }

    applyPreferredCalendarSelectionIfNeeded()
  }

  /// Applies the preferred or configured calendar when available.
  private func applyPreferredCalendarSelectionIfNeeded() {
    if let preferredCalendarName,
      let preferred = calendars.first(where: {
        $0.title.compare(
          preferredCalendarName,
          options: [.caseInsensitive, .diacriticInsensitive]
        ) == .orderedSame
      })
    {
      selectedCalendarID = preferred.id
      return
    }

    if selectedCalendarID.isEmpty, let firstCalendar = calendars.first {
      selectedCalendarID = firstCalendar.id
      return
    }

    if !calendars.contains(where: { $0.id == selectedCalendarID }) {
      selectedCalendarID = calendars.first?.id ?? ""
    }
  }

  /// Returns the currently selected calendar option when present.
  private var selectedCalendarOption: CalendarOption? {
    calendars.first { $0.id == selectedCalendarID }
  }
}

// MARK: - Defaults

extension MonthCalendarEventComposer {
  /// Returns the configured default alert option.
  private func resolvedDefaultAlert() -> AlertOption {
    AlertOption(rawValue: popupConfig.composerDefaultAlert) ?? .tenMinutes
  }

  /// Returns the configured default alert rows.
  private func resolvedDefaultAlertRows() -> [AlertRow] {
    let option = resolvedDefaultAlert()
    return option == .none ? [] : [.init(option: option)]
  }

  /// Resolves alert rows from saved lead times.
  private func resolvedAlertRows(from offsetsSeconds: [TimeInterval]) -> [AlertRow] {
    let resolved = offsetsSeconds.compactMap(resolvedAlertOption(from:)).map {
      AlertRow(option: $0)
    }
    return resolved.isEmpty ? [] : resolved
  }

  /// Resolves one alert option from one saved lead time.
  private func resolvedAlertOption(from seconds: TimeInterval) -> AlertOption? {
    switch Int(seconds.rounded()) {
    case 0:
      return .atTime
    case 300:
      return .fiveMinutes
    case 600:
      return .tenMinutes
    case 900:
      return .fifteenMinutes
    case 1800:
      return .thirtyMinutes
    case 3600:
      return .oneHour
    case 86_400:
      return .oneDay
    default:
      return nil
    }
  }

  /// Returns the configured default travel-time option.
  private func resolvedDefaultTravelTime() -> TravelTimeOption {
    TravelTimeOption(rawValue: popupConfig.composerDefaultTravelTime) ?? .none
  }

  /// Resolves one travel-time option from seconds.
  private func resolvedTravelTimeOption(from seconds: TimeInterval?) -> TravelTimeOption {
    guard let seconds else { return resolvedDefaultTravelTime() }

    switch Int(seconds.rounded()) {
    case 300:
      return .fiveMinutes
    case 600:
      return .tenMinutes
    case 900:
      return .fifteenMinutes
    case 1200:
      return .twentyMinutes
    case 1800:
      return .thirtyMinutes
    case 2700:
      return .fortyFiveMinutes
    case 3600:
      return .oneHour
    case 5400:
      return .ninetyMinutes
    case 7200:
      return .twoHours
    default:
      return .none
    }
  }

  /// Returns the current alert lead times in seconds.
  private func resolvedAlertOffsetsSeconds() -> [TimeInterval] {
    alertRows.compactMap(\.option.leadTimeSeconds)
  }
}

// MARK: - Event Building

extension MonthCalendarEventComposer {
  /// Returns the final start and end dates for the current form values.
  private func resolvedEventDates() -> (start: Date, end: Date) {
    if isAllDay {
      let startOfDay = calendar.startOfDay(for: startDate)
      let endDayStart = calendar.startOfDay(for: endDate)
      let endExclusive =
        calendar.date(byAdding: .day, value: 1, to: endDayStart)
        ?? endDayStart.addingTimeInterval(86_400)

      return (start: startOfDay, end: endExclusive)
    }

    let start = combinedDate(day: startDate, time: startTime)
    var end = combinedDate(day: endDate, time: endTime)

    if end <= start {
      end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
    }

    return (start: start, end: end)
  }

  /// Returns one date built from the selected day and time fields.
  private func combinedDate(day: Date, time: Date) -> Date {
    let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
    let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

    var merged = DateComponents()
    merged.year = dayComponents.year
    merged.month = dayComponents.month
    merged.day = dayComponents.day
    merged.hour = timeComponents.hour
    merged.minute = timeComponents.minute

    return calendar.date(from: merged) ?? day
  }

  /// Returns one default start time for new events on the selected day.
  private func defaultStartTime(on date: Date) -> Date {
    let startOfDay = calendar.startOfDay(for: date)
    return calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay
  }

  /// Returns one default end time for new events on the selected day.
  private func defaultEndTime(on date: Date) -> Date {
    let start = defaultStartTime(on: date)
    return calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
  }

  /// Resolves the stable EventKit event identifier from one popup event id.
  private func resolvedEventIdentifier(from event: NativeMonthCalendarEvent) -> String? {
    guard !event.id.hasPrefix("birthday-") else { return nil }

    let trimmedID = event.id
    let suffix = "-\(event.startDate.timeIntervalSince1970)"

    guard trimmedID.hasSuffix(suffix) else {
      return trimmedID.isEmpty ? nil : trimmedID
    }

    return String(trimmedID.dropLast(suffix.count))
  }

  /// Handles one create, update, or delete result.
  private func handleMutationResult(
    success: Bool,
    failureMessage: String?,
    successMessage: String,
    onSuccess: @escaping () -> Void
  ) {
    isSaving = false

    if success {
      infoMessage = successMessage
      onSuccess()
      return
    }

    errorMessage = "Failed: \(failureMessage ?? "unknown error")"
  }

  /// Normalizes optional user-entered text.
  private func normalizedOptionalText(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Clears transient user-facing messages.
  private func clearMessages() {
    errorMessage = nil
    infoMessage = nil
  }

  /// Adds one new alert row to the composer.
  func addAlert() {
    alertRows.append(.init(option: resolvedDefaultAlert()))
  }

  /// Removes one alert row from the composer.
  func removeAlert(id: UUID) {
    alertRows.removeAll { $0.id == id }
  }

  /// Updates one alert row selection.
  func setAlert(_ option: AlertOption, id: UUID) {
    guard let index = alertRows.firstIndex(where: { $0.id == id }) else { return }
    alertRows[index].option = option
  }

  /// Returns the configured title for one alert option.
  func title(for option: AlertOption) -> String {
    popupConfig.composerAlertLabels[option.rawValue] ?? option.fallbackTitle
  }

  /// Returns the configured title for one travel-time option.
  func title(for option: TravelTimeOption) -> String {
    popupConfig.composerTravelTimeLabels[option.rawValue] ?? option.fallbackTitle
  }
}
