import EasyBarShared
import Foundation

let calendarAgentLog = ProcessLogger(label: "easybar-calendar-agent")

/// Returns the calendar agent log path inside one logging directory.
func calendarAgentLogPath(in directory: String) -> String {
  URL(fileURLWithPath: directory)
    .appendingPathComponent("calendar-agent.out")
    .path
}
