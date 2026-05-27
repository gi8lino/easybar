#!/usr/bin/env swift
import CoreGraphics
import EventKit
import Foundation

private enum ScriptError: Error, LocalizedError {
  case calendarAccessDenied
  case invalidCurrentMonth
  case noWritableCalendarSource

  var errorDescription: String? {
    switch self {
    case .calendarAccessDenied:
      return "Calendar access was not granted. Allow access in System Settings > Privacy & Security > Calendars."
    case .invalidCurrentMonth:
      return "Could not determine the current month."
    case .noWritableCalendarSource:
      return "No writable calendar source found."
    }
  }
}

private let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--help") || arguments.contains("-h") {
  print(
    """
    Usage:
      ./scripts/populate-demo-calendar.swift
      ./scripts/populate-demo-calendar.swift demo

    Optional:
      CLEAR_EXISTING=false ./scripts/populate-demo-calendar.swift demo
    """)
  exit(0)
}

private let calendarName = arguments.first ?? "demo"
private let clearExisting = ProcessInfo.processInfo.environment["CLEAR_EXISTING"]?.lowercased() != "false"

private let store = EKEventStore()

/// Prints an error message and exits the script with a failure status.
private func fail(_ message: String) -> Never {
  fputs("\(message)\n", stderr)
  exit(1)
}

/// Requests read/write access to the user's calendars.
private func requestCalendarAccess() -> Bool {
  let semaphore = DispatchSemaphore(value: 0)
  var grantedResult = false

  if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { granted, error in
      if let error {
        fputs("Calendar access error: \(error.localizedDescription)\n", stderr)
      }

      grantedResult = granted
      semaphore.signal()
    }
  } else {
    store.requestAccess(to: .event) { granted, error in
      if let error {
        fputs("Calendar access error: \(error.localizedDescription)\n", stderr)
      }

      grantedResult = granted
      semaphore.signal()
    }
  }

  semaphore.wait()
  return grantedResult
}

/// Returns an existing calendar with the given name or creates a new one.
private func getOrCreateCalendar(named name: String) throws -> EKCalendar {
  if let existing = store.calendars(for: .event).first(where: { $0.title == name }) {
    return existing
  }

  let calendar = EKCalendar(for: .event, eventStore: store)
  calendar.title = name
  calendar.cgColor = CGColor(red: 0.15, green: 0.35, blue: 0.95, alpha: 1.0)

  guard
    let source =
      store.defaultCalendarForNewEvents?.source
      ?? store.sources.first(where: { $0.sourceType == .calDAV })
      ?? store.sources.first(where: { $0.sourceType == .local })
      ?? store.sources.first
  else {
    throw ScriptError.noWritableCalendarSource
  }

  calendar.source = source
  try store.saveCalendar(calendar, commit: true)

  return calendar
}

/// Picks a random value from a non-empty array.
private func pick<T>(_ values: [T]) -> T {
  values.randomElement()!
}

/// Returns a date in the current month for the given day and time.
private func dateFor(
  day: Int,
  minutesFromMidnight: Int,
  currentComponents: DateComponents,
  calendar: Calendar
) -> Date {
  var components = currentComponents
  components.day = day
  components.hour = minutesFromMidnight / 60
  components.minute = minutesFromMidnight % 60
  components.second = 0

  return calendar.date(from: components)!
}

/// Formats EventKit travel time for event notes.
private func travelLabel(_ seconds: TimeInterval) -> String {
  if seconds <= 0 {
    return "none"
  }

  return "\(Int(seconds / 60)) minutes"
}

do {
  guard requestCalendarAccess() else {
    throw ScriptError.calendarAccessDenied
  }

  let targetCalendar = try getOrCreateCalendar(named: calendarName)

  var systemCalendar = Calendar.current
  systemCalendar.timeZone = TimeZone.current

  let now = Date()
  let currentComponents = systemCalendar.dateComponents([.year, .month], from: now)

  guard
    let monthStart = systemCalendar.date(from: currentComponents),
    let monthEnd = systemCalendar.date(byAdding: .month, value: 1, to: monthStart),
    let dayRange = systemCalendar.range(of: .day, in: .month, for: monthStart)
  else {
    throw ScriptError.invalidCurrentMonth
  }

  if clearExisting {
    let predicate = store.predicateForEvents(
      withStart: monthStart,
      end: monthEnd,
      calendars: [targetCalendar]
    )

    let existingEvents = store.events(matching: predicate)

    for event in existingEvents {
      try store.remove(event, span: .thisEvent, commit: false)
    }

    try store.commit()
  }

  let titles = [
    "Team Sync",
    "Design Review",
    "Customer Call",
    "Focus Block",
    "Planning Session",
    "Coffee Chat",
    "Product Review",
    "Budget Check",
    "Interview",
    "Sprint Review",
    "Demo Prep",
    "Roadmap Discussion",
    "Workshop",
    "One-on-One",
    "Incident Review",
    "Architecture Review",
    "Partner Check-In",
    "Research Review",
  ]

  let locations = [
    "Office",
    "Home Office",
    "Client Site",
    "Zurich HB",
    "Conference Room A",
    "Conference Room B",
    "Cafe Central",
    "Google Meet",
    "Zoom",
    "On the train",
    "Remote",
    "Workshop Room",
    "Partner Office",
    "Focus Room",
  ]

  let modes = [
    "in person",
    "remote",
    "hybrid",
    "tentative",
    "busy",
    "free",
    "private notes",
    "follow-up needed",
    "high priority",
    "low priority",
  ]

  let durations = [30, 45, 60, 75, 90]

  let startSlots = [
    8 * 60,
    9 * 60,
    10 * 60,
    11 * 60,
    12 * 60,
    13 * 60,
    14 * 60,
    15 * 60,
    16 * 60,
    17 * 60,
    18 * 60,
  ]

  let alarmOffsets: [TimeInterval] = [
    -5 * 60,
    -10 * 60,
    -15 * 60,
    -30 * 60,
    -60 * 60,
  ]

  let travelTimes: [TimeInterval] = [
    5 * 60,
    10 * 60,
    15 * 60,
    20 * 60,
    30 * 60,
    45 * 60,
  ]

  var createdCount = 0
  var travelTimeSetCount = 0

  for day in dayRange {
    let appointmentsToday = Int.random(in: 2...5)
    let selectedSlots = Array(startSlots.shuffled().prefix(appointmentsToday)).sorted()

    for appointmentIndex in 0..<appointmentsToday {
      let startMinutes = selectedSlots[appointmentIndex]
      let durationMinutes = pick(durations)
      let endMinutes = startMinutes + durationMinutes

      let title = "\(pick(titles)) #\(day).\(appointmentIndex + 1)"
      let location = pick(locations)
      let mode = pick(modes)

      let shouldHaveTravelTime = Bool.random()
      let travelSeconds = shouldHaveTravelTime ? pick(travelTimes) : 0

      let event = EKEvent(eventStore: store)
      event.calendar = targetCalendar
      event.title = title
      event.startDate = dateFor(
        day: day,
        minutesFromMidnight: startMinutes,
        currentComponents: currentComponents,
        calendar: systemCalendar
      )
      event.endDate = dateFor(
        day: day,
        minutesFromMidnight: endMinutes,
        currentComponents: currentComponents,
        calendar: systemCalendar
      )
      event.location = location
      event.timeZone = TimeZone.current

      event.notes = """
        Generated demo appointment.
        Mode: \(mode)
        Duration: \(durationMinutes) minutes
        Travel time: \(travelLabel(travelSeconds))
        Seed: current-month-demo-data
        """

      if Bool.random() {
        event.url = URL(string: "https://example.test/demo-calendar/\(day)-\(appointmentIndex + 1)")
      }

      if Bool.random() {
        event.structuredLocation = EKStructuredLocation(title: location)
      }

      switch Int.random(in: 0...3) {
      case 0:
        event.availability = .busy
      case 1:
        event.availability = .free
      case 2:
        event.availability = .tentative
      default:
        event.availability = .unavailable
      }

      switch Int.random(in: 0...4) {
      case 0:
        event.addAlarm(EKAlarm(relativeOffset: pick(alarmOffsets)))
      case 1:
        event.addAlarm(EKAlarm(relativeOffset: -30 * 60))
        event.addAlarm(EKAlarm(relativeOffset: -5 * 60))
      case 2:
        event.addAlarm(EKAlarm(relativeOffset: -60 * 60))
      default:
        break
      }

      // Travel time support varies by macOS/EventKit version.
      if travelSeconds > 0, event.responds(to: NSSelectorFromString("setTravelTime:")) {
        event.setValue(travelSeconds, forKey: "travelTime")
        travelTimeSetCount += 1
      }

      try store.save(event, span: .thisEvent, commit: false)
      createdCount += 1
    }
  }

  try store.commit()

  print("Created \(createdCount) appointments in calendar \"\(calendarName)\" for the current month.")
  print("Events with actual EventKit travel time set: \(travelTimeSetCount).")
  print("Events without native travel-time support still include travel time in the notes.")
} catch {
  fail(error.localizedDescription)
}
