import SwiftUI

/// The application entry point.
@main
struct EasyBarApp: App {
  /// Bridges SwiftUI app lifecycle with AppKit lifecycle hooks.
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  /// Provides the minimal scene hierarchy required by SwiftUI.
  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
