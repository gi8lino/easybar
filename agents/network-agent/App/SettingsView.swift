import SwiftUI
import EasyBarShared

struct SettingsView: View {
    var body: some View {
        Form {
            Text("EasyBar Network Agent")
                .font(.headline)

            Text("Socket path")
                .font(.subheadline)

            Text(defaultNetworkAgentSocketPath())
                .font(.footnote)
                .textSelection(.enabled)
        }
        .padding(20)
        .frame(width: 420)
    }
}
