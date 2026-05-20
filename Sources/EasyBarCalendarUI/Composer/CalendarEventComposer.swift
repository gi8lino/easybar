import Combine
import EasyBarShared
import Foundation

/// View model for creating, editing, and deleting calendar events through injected actions.
@MainActor
public final class CalendarEventComposer: ObservableObject {
  public struct CalendarOption: Identifiable, Equatable {
    public let id: String
    public let title: String
    public init(id: String, title: String) {
      self.id = id
      self.title = title
    }
  }

  public struct AlertRow: Identifiable, Equatable {
    public let id: UUID
    public var option: AlertOption
    public var customMinutesText: String
    public init(id: UUID = UUID(), option: AlertOption, customMinutesText: String = "") {
      self.id = id
      self.option = option
      self.customMinutesText = customMinutesText
    }
  }

  public enum Mode {
    case create
    case edit(eventIdentifier: String)
  }

  enum Validation<Value> {
    case success(Value)
    case failure(String)
  }

  public enum AlertOption: String, CaseIterable, Identifiable {
    case none
    case atTime = "at_time"
    case fiveMinutes = "5_minutes"
    case tenMinutes = "10_minutes"
    case
      fifteenMinutes = "15_minutes"
    case thirtyMinutes = "30_minutes"
    case oneHour = "1_hour"
    case
      oneDay = "1_day"
    case custom
    public var id: String { rawValue }
    var fallbackTitle: String {
      switch self {
      case .none: "None"
      case .atTime: "At time of event"
      case .fiveMinutes: "5 minutes before"
      case .tenMinutes: "10 minutes before"
      case .fifteenMinutes: "15 minutes before"
      case .thirtyMinutes: "30 minutes before"
      case .oneHour: "1 hour before"
      case .oneDay: "1 day before"
      case .custom: "Custom"
      }
    }
    var leadTimeSeconds: TimeInterval? {
      switch self {
      case .none: nil
      case .atTime: 0
      case .fiveMinutes: 300
      case .tenMinutes: 600
      case .fifteenMinutes: 900
      case .thirtyMinutes: 1800
      case .oneHour: 3600
      case .oneDay: 86_400
      case .custom: nil
      }
    }
  }

  public enum TravelTimeOption: String, CaseIterable, Identifiable {
    case none
    case fiveMinutes = "5_minutes"
    case tenMinutes = "10_minutes"
    case fifteenMinutes = "15_minutes"
    case
      twentyMinutes = "20_minutes"
    case thirtyMinutes = "30_minutes"
    case fortyFiveMinutes = "45_minutes"
    case
      oneHour = "1_hour"
    case ninetyMinutes = "90_minutes"
    case twoHours = "2_hours"
    case custom
    public var id: String { rawValue }
    var fallbackTitle: String {
      switch self {
      case .none: "None"
      case .fiveMinutes: "5 minutes"
      case .tenMinutes: "10 minutes"
      case .fifteenMinutes: "15 minutes"
      case .twentyMinutes: "20 minutes"
      case .thirtyMinutes: "30 minutes"
      case .fortyFiveMinutes: "45 minutes"
      case .oneHour: "1 hour"
      case .ninetyMinutes: "1.5 hours"
      case .twoHours: "2 hours"
      case .custom: "Custom"
      }
    }
    var seconds: TimeInterval? {
      switch self {
      case .none: nil
      case .fiveMinutes: 300
      case .tenMinutes: 600
      case .fifteenMinutes: 900
      case .twentyMinutes: 1200
      case .thirtyMinutes: 1800
      case .fortyFiveMinutes: 2700
      case .oneHour: 3600
      case .ninetyMinutes: 5400
      case .twoHours: 7200
      case .custom: nil
      }
    }
  }

  @Published public private(set) var calendars: [CalendarOption] = []
  @Published public private(set) var accessGranted = false
  @Published public private(set) var isSaving = false
  @Published public private(set) var mode: Mode = .create
  @Published public var title = ""
  @Published public var startDate = Date()
  @Published public var endDate = Date()
  @Published public var startTime = Date()
  @Published public var endTime = Date()
  @Published public var isAllDay = false
  @Published public var selectedCalendarID = ""
  @Published public var location = ""
  @Published public var alertRows: [AlertRow] = [.init(option: .tenMinutes)]
  @Published public var travelTime: TravelTimeOption = .none
  @Published public var customTravelTimeMinutes = ""
  @Published public var errorMessage: String?
  @Published public var infoMessage: String?

  private let calendar = Calendar.current
  private let config: CalendarComposerConfig
  private let refreshSnapshots: () -> Void
  private let createEventAction: (CalendarAgentCreateEvent, @escaping (Bool, String?) -> Void) -> Void
  private let updateEventAction: (CalendarAgentUpdateEvent, @escaping (Bool, String?) -> Void) -> Void
  private let deleteEventAction: (CalendarAgentDeleteEvent, @escaping (Bool, String?) -> Void) -> Void
  private let openCalendarAppAction: () -> Void
  private var cancellables: Set<AnyCancellable> = []
  private var preferredCalendarID: String?
  private var preferredCalendarName: String?

  public init(
    config: CalendarComposerConfig,
    snapshotPublisher: AnyPublisher<CalendarAgentSnapshot?, Never>,
    refreshSnapshots: @escaping () -> Void,
    createEvent: @escaping (CalendarAgentCreateEvent, @escaping (Bool, String?) -> Void) -> Void,
    updateEvent: @escaping (CalendarAgentUpdateEvent, @escaping (Bool, String?) -> Void) -> Void,
    deleteEvent: @escaping (CalendarAgentDeleteEvent, @escaping (Bool, String?) -> Void) -> Void,
    openCalendarApp: @escaping () -> Void
  ) {
    self.config = config
    self.refreshSnapshots = refreshSnapshots
    self.createEventAction = createEvent
    self.updateEventAction = updateEvent
    self.deleteEventAction = deleteEvent
    self.openCalendarAppAction = openCalendarApp

    snapshotPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] snapshot in self?.applySnapshot(snapshot) }
      .store(in: &cancellables)
  }

  public var canSave: Bool {
    accessGranted && !isSaving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !selectedCalendarID.isEmpty
  }
  public var canDelete: Bool {
    if case .edit = mode { return accessGranted && !isSaving }
    return false
  }
  public var panelTitle: String {
    switch mode {
    case .create: config.createTitle
    case .edit: config.editTitle
    }
  }
  public var saveButtonTitle: String {
    switch mode {
    case .create: isSaving ? "\(config.saveLabel)..." : config.saveLabel
    case .edit: isSaving ? "\(config.updateLabel)..." : config.updateLabel
    }
  }

  public func prepare(defaultDate: Date) {
    mode = .create
    preferredCalendarID = nil
    preferredCalendarName = normalizedOptionalText(config.defaultCalendarName)
    let normalizedDate = calendar.startOfDay(for: defaultDate)
    reset(using: normalizedDate)
    refreshSnapshots()
  }

  public func prepare(event: CalendarAgentEvent) {
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
    let travelTimeSelection = resolvedTravelTimeSelection(from: event.travelTimeSeconds)
    travelTime = travelTimeSelection.option
    customTravelTimeMinutes = travelTimeSelection.customMinutesText
    preferredCalendarID = normalizedOptionalText(event.calendarID)
    preferredCalendarName = normalizedOptionalText(event.calendarName)
  }

  public func reset(using defaultDate: Date) {
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
    customTravelTimeMinutes = ""
    errorMessage = nil
    infoMessage = nil
    isSaving = false
  }

  public func save(onSuccess: @escaping () -> Void) {
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
    let resolvedAlertOffsetsSeconds: [TimeInterval]
    switch validatedAlertOffsetsSeconds() {
    case .success(let offsetsSeconds): resolvedAlertOffsetsSeconds = offsetsSeconds
    case .failure(let message):
      errorMessage = message
      return
    }
    let resolvedTravelTimeSeconds: TimeInterval?
    switch validatedTravelTimeSeconds() {
    case .success(let seconds): resolvedTravelTimeSeconds = seconds
    case .failure(let message):
      errorMessage = message
      return
    }
    isSaving = true
    switch mode {
    case .create:
      createEventAction(
        CalendarAgentCreateEvent(
          title: trimmedTitle, startDate: resolvedDates.start, endDate: resolvedDates.end, isAllDay: isAllDay,
          calendarID: selectedCalendar.id, location: normalizedOptionalText(location),
          alertOffsetsSeconds: resolvedAlertOffsetsSeconds, travelTimeSeconds: resolvedTravelTimeSeconds)
      ) { [weak self] success, message in
        self?.handleMutationResult(
          success: success, failureMessage: message, successMessage: "Appointment created.", onSuccess: onSuccess)
      }
    case .edit(let eventIdentifier):
      updateEventAction(
        CalendarAgentUpdateEvent(
          eventIdentifier: eventIdentifier, title: trimmedTitle, startDate: resolvedDates.start,
          endDate: resolvedDates.end, isAllDay: isAllDay, calendarID: selectedCalendar.id,
          location: normalizedOptionalText(location), alertOffsetsSeconds: resolvedAlertOffsetsSeconds,
          travelTimeSeconds: resolvedTravelTimeSeconds)
      ) { [weak self] success, message in
        self?.handleMutationResult(
          success: success, failureMessage: message, successMessage: "Appointment updated.", onSuccess: onSuccess)
      }
    }
  }

  public func delete(onSuccess: @escaping () -> Void) {
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
    deleteEventAction(CalendarAgentDeleteEvent(eventIdentifier: eventIdentifier)) { [weak self] success, message in
      self?.handleMutationResult(
        success: success, failureMessage: message, successMessage: "Appointment removed.", onSuccess: onSuccess)
    }
  }

  public func openCalendarApp() { openCalendarAppAction() }
  public func addAlert() { alertRows.append(.init(option: resolvedDefaultAlert())) }
  public func removeAlert(id: UUID) { alertRows.removeAll { $0.id == id } }
  public func setAlert(_ option: AlertOption, id: UUID) {
    guard let index = alertRows.firstIndex(where: { $0.id == id }) else { return }
    if option == .custom, alertRows[index].customMinutesText.isEmpty {
      alertRows[index].customMinutesText = defaultCustomMinutesText(for: alertRows[index].option)
    }
    alertRows[index].option = option
  }
  public func setCustomAlertMinutes(_ value: String, id: UUID) {
    guard let index = alertRows.firstIndex(where: { $0.id == id }) else { return }
    alertRows[index].customMinutesText = value
  }
  public func setTravelTime(_ option: TravelTimeOption) {
    if option == .custom, customTravelTimeMinutes.isEmpty {
      customTravelTimeMinutes = defaultCustomMinutesText(for: travelTime)
    }
    travelTime = option
  }
  public func customAlertMinutes(for id: UUID) -> String {
    alertRows.first(where: { $0.id == id })?.customMinutesText ?? ""
  }
  public func title(for option: AlertOption) -> String { config.alertLabels[option.rawValue] ?? option.fallbackTitle }
  public func title(for option: TravelTimeOption) -> String {
    config.travelTimeLabels[option.rawValue] ?? option.fallbackTitle
  }

  private func applySnapshot(_ snapshot: CalendarAgentSnapshot?) {
    guard let snapshot else {
      accessGranted = false
      calendars = []
      selectedCalendarID = ""
      return
    }
    accessGranted = snapshot.accessGranted
    calendars = snapshot.writableCalendars.map { CalendarOption(id: $0.id, title: $0.title) }
    applyPreferredCalendarSelectionIfNeeded()
  }
  private func applyPreferredCalendarSelectionIfNeeded() {
    if let preferredCalendarID, let preferred = calendars.first(where: { $0.id == preferredCalendarID }) {
      selectedCalendarID = preferred.id
      return
    }
    if let preferredCalendarName,
      let preferred = calendars.first(where: {
        $0.title.compare(preferredCalendarName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
      })
    {
      selectedCalendarID = preferred.id
      return
    }
    if selectedCalendarID.isEmpty, let firstCalendar = calendars.first {
      selectedCalendarID = firstCalendar.id
      return
    }
    if !calendars.contains(where: { $0.id == selectedCalendarID }) { selectedCalendarID = calendars.first?.id ?? "" }
  }
  private var selectedCalendarOption: CalendarOption? { calendars.first { $0.id == selectedCalendarID } }
  private func resolvedDefaultAlert() -> AlertOption { AlertOption(rawValue: config.defaultAlert) ?? .tenMinutes }
  private func resolvedDefaultAlertRows() -> [AlertRow] {
    let option = resolvedDefaultAlert()
    return option == .none ? [] : [AlertRow(option: option)]
  }

  private func resolvedAlertRows(from offsetsSeconds: [TimeInterval]) -> [AlertRow] {
    let resolved = offsetsSeconds.compactMap(resolvedAlertRow(from:))
    return resolved.isEmpty ? [] : resolved
  }

  private func resolvedAlertRow(from seconds: TimeInterval) -> AlertRow? {
    guard seconds >= 0 else { return nil }

    switch Int(seconds.rounded()) {
    case 0:
      return AlertRow(option: .atTime)
    case 300:
      return AlertRow(option: .fiveMinutes)
    case 600:
      return AlertRow(option: .tenMinutes)
    case 900:
      return AlertRow(option: .fifteenMinutes)
    case 1800:
      return AlertRow(option: .thirtyMinutes)
    case 3600:
      return AlertRow(option: .oneHour)
    case 86_400:
      return AlertRow(option: .oneDay)
    default:
      return AlertRow(option: .custom, customMinutesText: customMinutesText(from: seconds))
    }
  }
  private func resolvedDefaultTravelTime() -> TravelTimeOption {
    TravelTimeOption(rawValue: config.defaultTravelTime) ?? .none
  }
  private func resolvedTravelTimeSelection(from seconds: TimeInterval?)
    -> (option: TravelTimeOption, customMinutesText: String)
  {
    guard let seconds else { return (.none, "") }

    switch Int(seconds.rounded()) {
    case 300:
      return (.fiveMinutes, "")
    case 600:
      return (.tenMinutes, "")
    case 900:
      return (.fifteenMinutes, "")
    case 1200:
      return (.twentyMinutes, "")
    case 1800:
      return (.thirtyMinutes, "")
    case 2700:
      return (.fortyFiveMinutes, "")
    case 3600:
      return (.oneHour, "")
    case 5400:
      return (.ninetyMinutes, "")
    case 7200:
      return (.twoHours, "")
    default:
      return (.custom, customMinutesText(from: seconds))
    }
  }
  private func validatedAlertOffsetsSeconds() -> Validation<[TimeInterval]> {
    var offsetsSeconds: [TimeInterval] = []

    for row in alertRows {
      switch validatedAlertOffsetSeconds(for: row) {
      case .success(let offset):
        if let offset {
          offsetsSeconds.append(offset)
        }
      case .failure(let message):
        return .failure(message)
      }
    }

    return .success(offsetsSeconds)
  }

  private func validatedAlertOffsetSeconds(for row: AlertRow) -> Validation<TimeInterval?> {
    if row.option != .custom {
      return .success(row.option.leadTimeSeconds)
    }

    switch validatedCustomMinutes(
      row.customMinutesText,
      emptyMessage: "Enter custom alert minutes.",
      invalidMessage: "Custom alert minutes must be a positive whole number."
    ) {
    case .success(let minutes):
      return .success(TimeInterval(minutes * 60))
    case .failure(let message):
      return .failure(message)
    }
  }

  private func validatedTravelTimeSeconds() -> Validation<TimeInterval?> {
    if travelTime != .custom {
      return .success(travelTime.seconds)
    }

    switch validatedCustomMinutes(
      customTravelTimeMinutes,
      emptyMessage: "Enter custom travel time minutes.",
      invalidMessage: "Custom travel time minutes must be a positive whole number."
    ) {
    case .success(let minutes):
      return .success(TimeInterval(minutes * 60))
    case .failure(let message):
      return .failure(message)
    }
  }
  private func validatedCustomMinutes(_ value: String, emptyMessage: String, invalidMessage: String) -> Validation<Int>
  {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return .failure(emptyMessage) }
    guard let minutes = Int(trimmed), minutes > 0 else { return .failure(invalidMessage) }
    return .success(minutes)
  }
  private func customMinutesText(from seconds: TimeInterval) -> String { String(max(1, Int((seconds / 60).rounded()))) }
  private func resolvedEventDates() -> (start: Date, end: Date) {
    if isAllDay {
      let startOfDay = calendar.startOfDay(for: startDate)
      let endDayStart = calendar.startOfDay(for: endDate)
      let endExclusive =
        calendar.date(byAdding: .day, value: 1, to: endDayStart) ?? endDayStart.addingTimeInterval(86_400)
      return (startOfDay, endExclusive)
    }
    let start = combinedDate(day: startDate, time: startTime)
    var end = combinedDate(day: endDate, time: endTime)
    if end <= start { end = calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600) }
    return (start, end)
  }
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
  private func defaultStartTime(on date: Date) -> Date {
    let startOfDay = calendar.startOfDay(for: date)
    return calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? startOfDay
  }
  private func defaultEndTime(on date: Date) -> Date {
    let start = defaultStartTime(on: date)
    return calendar.date(byAdding: .hour, value: 1, to: start) ?? start.addingTimeInterval(3600)
  }
  private func resolvedEventIdentifier(from event: CalendarAgentEvent) -> String? {
    guard !event.id.hasPrefix("birthday-") else { return nil }
    let trimmedID = event.id
    let suffix = "-\(event.startDate.timeIntervalSince1970)"
    guard trimmedID.hasSuffix(suffix) else { return trimmedID.isEmpty ? nil : trimmedID }
    return String(trimmedID.dropLast(suffix.count))
  }
  private func handleMutationResult(
    success: Bool, failureMessage: String?, successMessage: String, onSuccess: @escaping () -> Void
  ) {
    isSaving = false
    if success {
      infoMessage = successMessage
      onSuccess()
      return
    }
    errorMessage = "Failed: \(failureMessage ?? "unknown error")"
  }
  private func normalizedOptionalText(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
  private func clearMessages() {
    errorMessage = nil
    infoMessage = nil
  }
  private func defaultCustomMinutesText(for option: AlertOption) -> String {
    guard let seconds = option.leadTimeSeconds, seconds > 0 else { return "" }
    return customMinutesText(from: seconds)
  }
  private func defaultCustomMinutesText(for option: TravelTimeOption) -> String {
    guard let seconds = option.seconds, seconds > 0 else { return "" }
    return customMinutesText(from: seconds)
  }
}
