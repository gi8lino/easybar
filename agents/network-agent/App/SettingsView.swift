import EasyBarShared
import SwiftUI

struct SettingsView: View {
  private let runtimeConfig = SharedRuntimeConfig.current

  var body: some View {
    Form {
      Text("EasyBar Network Agent")
        .font(.headline)

      Text("Socket path")
        .font(.subheadline)

      Text(runtimeConfig.networkAgentSocketPath)
        .font(.footnote)
        .textSelection(.enabled)
    }
    .padding(20)
    .frame(width: 420)
  }
}
