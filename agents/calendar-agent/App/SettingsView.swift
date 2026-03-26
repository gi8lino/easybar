import EasyBarShared
import SwiftUI

struct SettingsView: View {
  var body: some View {
    Form {
      Text("EasyBar Calendar Agent")
        .font(.headline)

      Text("Socket path")
        .font(.subheadline)

      Text(defaultCalendarAgentSocketPath())
        .font(.footnote)
        .textSelection(.enabled)
    }
    .padding(20)
    .frame(width: 420)
  }
}
