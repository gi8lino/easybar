import EasyBarShared
import SwiftUI

struct SettingsView: View {
  private let runtimeConfig = SharedRuntimeConfig.current

  var body: some View {
    AgentSettingsView(
      title: "EasyBar Network Agent",
      socketPath: runtimeConfig.networkAgentSocketPath
    )
  }
}
