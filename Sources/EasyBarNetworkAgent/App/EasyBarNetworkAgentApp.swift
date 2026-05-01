import SwiftUI

/// SwiftUI entry point for the network agent app.
///
/// The app delegates lifecycle handling to `AppDelegate` and does not
/// expose a user-facing window.
@main
struct EasyBarNetworkAgentApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  /// Provides the minimal scene hierarchy required by SwiftUI.
  ///
  /// The network agent runs as an accessory process, so the Settings scene
  /// intentionally renders no visible content.
  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
