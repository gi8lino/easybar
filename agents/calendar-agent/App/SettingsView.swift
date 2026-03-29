import EasyBarShared
import SwiftUI

struct SettingsView: View {
  private let runtimeConfig = SharedRuntimeConfig.current

  /// Renders the calendar agent settings summary.
  var body: some View {
    AgentSettingsView(
      title: "EasyBar Calendar Agent",
      socketPath: runtimeConfig.calendarAgentSocketPath
    )
  }
}
