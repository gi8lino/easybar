import SwiftUI

/// SwiftUI entry point for the calendar agent app.
///
/// Lifecycle work is delegated to `AppDelegate`; the agent does not
/// expose a user-facing window.
@main
struct EasyBarCalendarAgentApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  /// Provides the minimal scene hierarchy required by SwiftUI.
  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
