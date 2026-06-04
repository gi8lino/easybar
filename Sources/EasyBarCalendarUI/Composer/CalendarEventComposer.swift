import Combine
import EasyBarCalendarPresentation
import EasyBarShared
import Foundation

/// View model for creating, editing, and deleting calendar events through injected actions.
@MainActor
public final class CalendarEventComposer: ObservableObject {
  /// Stable picker item describing one writable calendar.
  public struct CalendarOption: Identifiable, Equatable {
    /// Stable calendar identifier.
    public let id: String

    /// Human-readable calendar title.
    public let title: String

    /// Creates one selectable calendar option.
    public init(id: String, title: String) {
      self.id = id
      self.title = title
    }
  }

  /// Mutable row backing one alert selection entry.
  public struct AlertRow: Identifiable, Equatable {
    /// Stable row identifier for SwiftUI diffing.
    public let id: UUID

    /// Selected alert preset.
    public var option: AlertOption

    /// Custom alert lead time in minutes when `option == .custom`.
    public var customMinutesText: String

    /// Creates one alert row.
    public init(id: UUID = UUID(), option: AlertOption, customMinutesText: String = "") {
      self.id = id
      self.option = option
      self.customMinutesText = customMinutesText
    }
  }

  /// Composer mode.
  public enum Mode: Equatable {
    case create
    case edit(eventIdentifier: String)
  }

  /// Alert presets supported by the composer.
  public enum AlertOption: String, CaseIterable, Identifiable {
    case none
    case atTime = "at_time"
    case fiveMinutes = "5_minutes"
    case tenMinutes = "10_minutes"
    case fifteenMinutes = "15_minutes"
    case thirtyMinutes = "30_minutes"
    case oneHour = "1_hour"
    case oneDay = "1_day"
    case custom

    public var id: String { rawValue }

    var leadTimeSeconds: TimeInterval? {
      switch self {
      case .none:
        return nil
      case .atTime:
        return 0
      case .fiveMinutes:
        return 5 * 60
      case .tenMinutes:
        return 10 * 60
      case .fifteenMinutes:
        return 15 * 60
      case .thirtyMinutes:
        return 30 * 60
      case .oneHour:
        return 60 * 60
      case .oneDay:
        return 24 * 60 * 60
      case .custom:
        return nil
      }
    }

    private var fallbackTitle: String {
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
      case .custom:
        return "Custom"
      }
    }

    static func from(configValue: String) -> AlertOption {
      AlertOption(rawValue: configValue) ?? .oneHour
    }

    func title(config: CalendarComposerConfig) -> String {
      switch self {
      case .custom:
        return fallbackTitle
      default:
        return config.alertLabels[rawValue] ?? fallbackTitle
      }
    }
  }

  /// Travel-time presets supported by the composer.
  public enum TravelTimeOption: String, CaseIterable, Identifiable {
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
    case custom

    public var id: String { rawValue }

    var seconds: TimeInterval? {
      switch self {
      case .none:
        return nil
      case .fiveMinutes:
        return 5 * 60
      case .tenMinutes:
        return 10 * 60
      case .fifteenMinutes:
        return 15 * 60
      case .twentyMinutes:
        return 20 * 60
      case .thirtyMinutes:
        return 30 * 60
      case .fortyFiveMinutes:
        return 45 * 60
      case .oneHour:
        return 60 * 60
      case .ninetyMinutes:
        return 90 * 60
      case .twoHours:
        return 2 * 60 * 60
      case .custom:
        return nil
      }
    }

    private var fallbackTitle: String {
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
      case .custom:
        return "Custom"
      }
    }

    static func from(configValue: String) -> TravelTimeOption {
      TravelTimeOption(rawValue: configValue) ?? .none
    }

    func title(config: CalendarComposerConfig) -> String {
      switch self {
      case .custom:
        return fallbackTitle
      default:
        return config.travelTimeLabels[rawValue] ?? fallbackTitle
      }
    }
  }

  private struct Draft {
    let title: String
    let location: String?
    let calendarID: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let alertOffsetsSeconds: [TimeInterval]
    let travelTimeSeconds: TimeInterval?
  }

  private enum Validation<Value> {
    case success(Value)
    case failure(String)
  }

  @Published public private(set) var mode: Mode = .create
  @Published public var title = ""
  @Published public var location = ""
  @Published public var selectedCalendarID = ""
  @Published public var startDate = Date()
  @Published public var endDate = Date()
  @Published public var isAllDay = false
  @Published public var selectedTravelTime: TravelTimeOption = .none
  @Published public var customTravelMinutesText = ""
  @Published public var alertRows: [AlertRow] = []
  @Published public private(set) var calendarOptions: [CalendarOption] = []
  @Published public private(set) var errorMessage: String?
  @Published public private(set) var infoMessage: String?
  @Published public private(set) var isSaving = false
  @Published public private(set) var accessGranted = true

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
      .receive(on: RunLoop.main)
      .sink { [weak self] snapshot in
        self?.applySnapshot(snapshot)
      }
      .store(in: &cancellables)

    reset(using: Date())
  }

  /// Returns whether the current form contents can be saved.
  public var canSave: Bool {
    accessGranted
      && !isSaving
      && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !selectedCalendarID.isEmpty
  }

  /// Returns whether the currently loaded event can be deleted.
  public var canDelete: Bool {
    guard case .edit = mode else { return false }
    return accessGranted && !isSaving
  }

  /// Returns the current panel title.
  public var panelTitle: String {
    switch mode {
    case .create:
      return config.createTitle
    case .edit:
      return config.editTitle
    }
  }

  /// Returns the available alert options.
  public var alertOptions: [AlertOption] {
    AlertOption.allCases
  }

  /// Returns the available travel-time options.
  public var travelTimeOptions: [TravelTimeOption] {
    TravelTimeOption.allCases
  }

  /// Returns a localized or configured label for an alert option.
  public func alertLabel(for option: AlertOption) -> String {
    option.title(config: config)
  }

  /// Returns a localized or configured label for a travel-time option.
  public func travelTimeLabel(for option: TravelTimeOption) -> String {
    option.title(config: config)
  }

  /// Adds one new alert row.
  public func addAlertRow() {
    alertRows.append(AlertRow(option: .tenMinutes))
  }

  /// Removes one alert row.
  public func removeAlertRow(id: UUID) {
    guard alertRows.count > 1 else {
      alertRows = [AlertRow(option: .none)]
      return
    }

    alertRows.removeAll { $0.id == id }
  }

  /// Prepares the composer for creating a new event.
  public func prepare(defaultDate: Date) {
    mode = .create
    preferredCalendarID = nil
    preferredCalendarName = normalizedOptionalText(config.defaultCalendarName)

    reset(using: defaultDate)
    clearMessages()
    refreshSnapshots()
  }

  /// Prepares the composer for editing an existing event.
  public func prepare(event: CalendarAgentEvent) {
    clearMessages()

    guard let eventIdentifier = event.eventIdentifier ?? resolvedEventIdentifier(from: event) else {
      mode = .create
      reset(using: event.startDate)
      errorMessage = "This appointment cannot be edited."
      refreshSnapshots()
      return
    }

    mode = .edit(eventIdentifier: eventIdentifier)
    title = event.title
    location = event.location ?? ""
    preferredCalendarID = event.calendarID
    preferredCalendarName = event.calendarName
    selectedCalendarID = event.calendarID ?? selectedCalendarID
    startDate = event.startDate
    endDate = displayedEndDate(for: event)
    isAllDay = event.isAllDay

    selectedTravelTime =
      travelOption(for: event.travelTimeSeconds)
      ?? (event.travelTimeSeconds == nil ? .none : .custom)

    customTravelMinutesText = customMinutesText(
      knownSeconds: selectedTravelTime.seconds,
      actualSeconds: event.travelTimeSeconds
    )

    alertRows = initialAlertRows(
      offsets: event.alertOffsetsSeconds,
      defaultAlert: config.defaultAlert
    )

    refreshSnapshots()
  }

  /// Saves the current form as a create or update mutation.
  public func save(onSuccess: @escaping () -> Void) {
    clearMessages()

    switch makeDraft() {
    case .failure(let message):
      errorMessage = message

    case .success(let draft):
      isSaving = true

      switch mode {
      case .create:
        createEventAction(makeCreateEvent(from: draft)) { [weak self] success, message in
          Task { @MainActor in
            self?.handleMutationResult(
              success: success,
              failureMessage: message,
              successMessage: "Appointment created.",
              onSuccess: onSuccess
            )
          }
        }

      case .edit(let eventIdentifier):
        updateEventAction(makeUpdateEvent(from: draft, eventIdentifier: eventIdentifier)) {
          [weak self] success, message in
          Task { @MainActor in
            self?.handleMutationResult(
              success: success,
              failureMessage: message,
              successMessage: "Appointment updated.",
              onSuccess: onSuccess
            )
          }
        }
      }
    }
  }

  /// Deletes the current event.
  public func delete(onSuccess: @escaping () -> Void) {
    clearMessages()

    guard case .edit(let eventIdentifier) = mode else {
      errorMessage = "No appointment is selected."
      return
    }

    isSaving = true

    deleteEventAction(CalendarAgentDeleteEvent(eventIdentifier: eventIdentifier)) { [weak self] success, message in
      Task { @MainActor in
        self?.handleMutationResult(
          success: success,
          failureMessage: message,
          successMessage: "Appointment removed.",
          onSuccess: onSuccess
        )
      }
    }
  }

  /// Opens Calendar.app.
  public func openCalendarApp() {
    openCalendarAppAction()
  }

  private func applySnapshot(_ snapshot: CalendarAgentSnapshot?) {
    accessGranted = snapshot?.accessGranted ?? false

    let options =
      snapshot?
      .writableCalendars
      .map { CalendarOption(id: $0.id, title: $0.title) }
      ?? []

    calendarOptions = options

    guard !options.isEmpty else {
      selectedCalendarID = ""
      return
    }

    if let preferredCalendarID,
      options.contains(where: { $0.id == preferredCalendarID })
    {
      selectedCalendarID = preferredCalendarID
      return
    }

    if !selectedCalendarID.isEmpty,
      options.contains(where: { $0.id == selectedCalendarID })
    {
      return
    }

    if let preferredCalendarName,
      let match = options.first(where: {
        $0.title.localizedCaseInsensitiveCompare(preferredCalendarName) == .orderedSame
      })
    {
      selectedCalendarID = match.id
      return
    }

    selectedCalendarID = options[0].id
  }

  private func reset(using date: Date) {
    let defaultStart = defaultStartTime(on: date)
    let defaultEnd = defaultEndTime(on: date)

    title = ""
    location = ""
    startDate = defaultStart
    endDate = defaultEnd
    isAllDay = false
    selectedTravelTime = TravelTimeOption.from(configValue: config.defaultTravelTime)
    customTravelMinutesText = defaultCustomMinutesText(for: selectedTravelTime)
    alertRows = [AlertRow(option: AlertOption.from(configValue: config.defaultAlert))]
    selectedCalendarID = resolvedInitialCalendarID()
  }

  private func resolvedInitialCalendarID() -> String {
    if let preferredCalendarID,
      calendarOptions.contains(where: { $0.id == preferredCalendarID })
    {
      return preferredCalendarID
    }

    if let preferredCalendarName,
      let match = calendarOptions.first(where: {
        $0.title.localizedCaseInsensitiveCompare(preferredCalendarName) == .orderedSame
      })
    {
      return match.id
    }

    if !selectedCalendarID.isEmpty,
      calendarOptions.contains(where: { $0.id == selectedCalendarID })
    {
      return selectedCalendarID
    }

    return calendarOptions.first?.id ?? ""
  }

  private func makeDraft() -> Validation<Draft> {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedTitle.isEmpty else {
      return .failure("Title is required.")
    }

    guard !selectedCalendarID.isEmpty else {
      return .failure("No writable calendar is selected.")
    }

    switch normalizedDateRange() {
    case .failure(let message):
      return .failure(message)

    case .success(let range):
      switch normalizedTravelTimeSeconds() {
      case .failure(let message):
        return .failure(message)

      case .success(let travelTimeSeconds):
        switch normalizedAlertOffsets() {
        case .failure(let message):
          return .failure(message)

        case .success(let alertOffsetsSeconds):
          return .success(
            Draft(
              title: trimmedTitle,
              location: normalizedOptionalText(location),
              calendarID: selectedCalendarID,
              startDate: range.start,
              endDate: range.end,
              isAllDay: isAllDay,
              alertOffsetsSeconds: alertOffsetsSeconds,
              travelTimeSeconds: travelTimeSeconds
            )
          )
        }
      }
    }
  }

  private func makeCreateEvent(from draft: Draft) -> CalendarAgentCreateEvent {
    CalendarAgentCreateEvent(
      title: draft.title,
      startDate: draft.startDate,
      endDate: draft.endDate,
      isAllDay: draft.isAllDay,
      calendarID: draft.calendarID,
      location: draft.location,
      alertOffsetsSeconds: draft.alertOffsetsSeconds,
      travelTimeSeconds: draft.travelTimeSeconds
    )
  }

  private func makeUpdateEvent(
    from draft: Draft,
    eventIdentifier: String
  ) -> CalendarAgentUpdateEvent {
    CalendarAgentUpdateEvent(
      eventIdentifier: eventIdentifier,
      title: draft.title,
      startDate: draft.startDate,
      endDate: draft.endDate,
      isAllDay: draft.isAllDay,
      calendarID: draft.calendarID,
      location: draft.location,
      alertOffsetsSeconds: draft.alertOffsetsSeconds,
      travelTimeSeconds: draft.travelTimeSeconds
    )
  }

  private func normalizedDateRange() -> Validation<(start: Date, end: Date)> {
    if isAllDay {
      let startOfDay = calendar.startOfDay(for: startDate)
      let endDay = calendar.startOfDay(for: max(startDate, endDate))
      let exclusiveEnd =
        calendar.date(byAdding: .day, value: 1, to: endDay)
        ?? endDay.addingTimeInterval(86_400)

      return .success((startOfDay, exclusiveEnd))
    }

    guard endDate > startDate else {
      return .failure("End time must be after start time.")
    }

    return .success((startDate, endDate))
  }

  private func normalizedTravelTimeSeconds() -> Validation<TimeInterval?> {
    guard selectedTravelTime == .custom else {
      return .success(selectedTravelTime.seconds)
    }

    let trimmed = customTravelMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmed.isEmpty else {
      return .success(nil)
    }

    guard let minutes = Int(trimmed), minutes >= 0 else {
      return .failure("Travel time must be a positive number of minutes.")
    }

    return .success(TimeInterval(minutes * 60))
  }

  private func normalizedAlertOffsets() -> Validation<[TimeInterval]> {
    var offsets: [TimeInterval] = []

    for row in alertRows {
      switch row.option {
      case .none:
        continue

      case .custom:
        let trimmed = row.customMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let minutes = Int(trimmed), minutes >= 0 else {
          return .failure("Custom alerts must be positive numbers of minutes.")
        }

        offsets.append(TimeInterval(minutes * 60))

      default:
        if let seconds = row.option.leadTimeSeconds {
          offsets.append(seconds)
        }
      }
    }

    return .success(offsets)
  }

  private func initialAlertRows(
    offsets: [TimeInterval],
    defaultAlert: String
  ) -> [AlertRow] {
    guard !offsets.isEmpty else {
      return [AlertRow(option: AlertOption.from(configValue: defaultAlert))]
    }

    return offsets.map { offset in
      if let option = alertOption(for: offset) {
        return AlertRow(
          option: option,
          customMinutesText: defaultCustomMinutesText(for: option)
        )
      }

      return AlertRow(
        option: .custom,
        customMinutesText: customMinutesText(from: offset)
      )
    }
  }

  private func alertOption(for seconds: TimeInterval) -> AlertOption? {
    AlertOption.allCases.first { option in
      guard let leadTimeSeconds = option.leadTimeSeconds else { return false }
      return Int(leadTimeSeconds) == Int(seconds)
    }
  }

  private func travelOption(for seconds: TimeInterval?) -> TravelTimeOption? {
    guard let seconds else { return nil }

    return TravelTimeOption.allCases.first { option in
      guard let optionSeconds = option.seconds else { return false }
      return Int(optionSeconds) == Int(seconds)
    }
  }

  private func displayedEndDate(for event: CalendarAgentEvent) -> Date {
    guard event.isAllDay else {
      return event.endDate
    }

    let startDay = calendar.startOfDay(for: event.startDate)
    let endDay = calendar.startOfDay(for: event.endDate)

    guard endDay > startDay else {
      return startDay
    }

    return calendar.date(byAdding: .day, value: -1, to: endDay) ?? startDay
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
    guard !event.id.hasPrefix("birthday-") else {
      return nil
    }

    let suffix = "-\(event.startDate.timeIntervalSince1970)"

    guard event.id.hasSuffix(suffix) else {
      return event.id.isEmpty ? nil : event.id
    }

    let resolved = String(event.id.dropLast(suffix.count))
    return resolved.isEmpty ? nil : resolved
  }

  private func handleMutationResult(
    success: Bool,
    failureMessage: String?,
    successMessage: String,
    onSuccess: @escaping () -> Void
  ) {
    isSaving = false

    guard success else {
      errorMessage = "Failed: \(failureMessage ?? "unknown error")"
      return
    }

    infoMessage = successMessage
    refreshSnapshots()
    onSuccess()
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
    guard let seconds = option.leadTimeSeconds, seconds > 0 else {
      return ""
    }

    return customMinutesText(from: seconds)
  }

  private func defaultCustomMinutesText(for option: TravelTimeOption) -> String {
    guard let seconds = option.seconds, seconds > 0 else {
      return ""
    }

    return customMinutesText(from: seconds)
  }

  private func customMinutesText(knownSeconds: TimeInterval?, actualSeconds: TimeInterval?) -> String {
    guard knownSeconds == nil, let actualSeconds else {
      return ""
    }

    return customMinutesText(from: actualSeconds)
  }

  private func customMinutesText(from seconds: TimeInterval) -> String {
    "\(max(0, Int((seconds / 60).rounded())))"
  }
}
