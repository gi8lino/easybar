import EasyBarShared
import SwiftUI

struct SettingsView: View {
  private let runtimeConfig = SharedRuntimeConfig.current

  var body: some View {
    Form {
      Text("EasyBar Calendar Agent")
        .font(.headline)

      Text("Socket path")
        .font(.subheadline)

      Text(runtimeConfig.calendarAgentSocketPath)
        .font(.footnote)
        .textSelection(.enabled)
    }
    .padding(20)
    .frame(width: 420)
  }
}
