import SwiftUI

/// The application entry point.
@main
struct EasyBarApp: App {
  init() {
    _ = AppValidationMode.runIfRequested()
  }

  /// Bridges SwiftUI app lifecycle with AppKit lifecycle hooks.
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  /// Provides the minimal scene hierarchy required by SwiftUI.
  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
