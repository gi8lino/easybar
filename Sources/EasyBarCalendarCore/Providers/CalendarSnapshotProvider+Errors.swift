import Foundation

/// Errors raised while creating or updating calendar events.
enum CalendarAgentCreateError: LocalizedError {
  case accessDenied
  case invalidDateRange
  case noWritableCalendar
  case eventIdentifierUnavailable

  var errorDescription: String? {
    switch self {
    case .accessDenied:
      return "Calendar access is not available."
    case .invalidDateRange:
      return "The end time must be after the start time."
    case .noWritableCalendar:
      return "No writable calendar is available."
    case .eventIdentifierUnavailable:
      return "Calendar did not return a stable identifier for the saved appointment."
    }
  }
}

/// Errors raised while mutating existing calendar events.
enum CalendarAgentMutationError: LocalizedError {
  case eventNotFound

  var errorDescription: String? {
    switch self {
    case .eventNotFound:
      return "The selected appointment could not be found."
    }
  }
}
