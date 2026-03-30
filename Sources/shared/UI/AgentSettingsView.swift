import SwiftUI

/// Shared settings content for simple agent windows.
public struct AgentSettingsView: View {
  private let title: String
  private let socketPath: String

  /// Creates one agent settings view.
  public init(title: String, socketPath: String) {
    self.title = title
    self.socketPath = socketPath
  }

  public var body: some View {
    Form {
      Text(title)
        .font(.headline)

      Text("Socket path")
        .font(.subheadline)

      Text(socketPath)
        .font(.footnote)
        .textSelection(.enabled)
    }
    .padding(20)
    .frame(width: 420)
  }
}
