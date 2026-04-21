import AppKit
import SwiftUI

/// Presents a floating window that explains config load or reload failures.
@MainActor
final class ConfigErrorWindowController: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var hostingController = NSHostingController(rootView: AnyView(EmptyView()))

  /// Presents the current config failure state in a dedicated floating window.
  func present(failureState: Config.LoadFailureState, configPath: String) {
    hostingController.rootView = AnyView(
      ConfigErrorContentView(
        state: failureState,
        configPath: configPath,
        onClose: { [weak self] in
          self?.close()
        }
      )
    )

    let window = window ?? makeWindow()
    self.window = window

    hostingController.view.layoutSubtreeIfNeeded()
    let fittingSize = hostingController.view.fittingSize
    guard fittingSize.width > 0, fittingSize.height > 0 else { return }

    window.setContentSize(fittingSize)
    center(window: window, size: fittingSize)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Closes the config error window when it is currently shown.
  func close() {
    window?.close()
    reset()
  }

  /// Builds the floating config error window shell.
  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "EasyBar Config Error"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.level = .floating
    window.hasShadow = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    window.backgroundColor = .clear
    window.isOpaque = false
    window.representedURL = nil
    window.miniwindowImage = NSApp.applicationIconImage
    window.standardWindowButton(.documentIconButton)?.image = NSApp.applicationIconImage
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.contentViewController = hostingController
    window.delegate = self
    return window
  }

  /// Centers the floating error window over the active window or main screen.
  private func center(window: NSWindow, size: CGSize) {
    if let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow {
      let parentFrame = parentWindow.frame
      window.setFrameOrigin(
        NSPoint(
          x: parentFrame.midX - size.width / 2,
          y: parentFrame.midY - size.height / 2
        )
      )
      return
    }

    if let screenFrame = NSScreen.main?.visibleFrame {
      window.setFrameOrigin(
        NSPoint(
          x: screenFrame.midX - size.width / 2,
          y: screenFrame.midY - size.height / 2
        )
      )
    }
  }

  /// Resets all retained window/controller state after close.
  private func reset() {
    window = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }

  /// Resets controller state when the user closes the window directly.
  func windowWillClose(_ notification: Notification) {
    reset()
  }
}

private struct ConfigErrorContentView: View {
  let state: Config.LoadFailureState
  let configPath: String
  let onClose: () -> Void

  private var configError: ConfigError? {
    state.error as? ConfigError
  }

  private var issuePathText: String? {
    configError?.configPath
  }

  private var detailText: String {
    if let configError {
      return configError.detail
    }

    return normalizedText(state.error.localizedDescription)
  }

  private var title: String {
    switch state.context {
    case .initialLoad:
      return "EasyBar started with a config problem"
    case .reloadKeptPreviousConfig:
      return "EasyBar could not apply the new config"
    }
  }

  private var summary: String {
    switch state.context {
    case .initialLoad:
      return "The bar is running with fallback defaults until the config is fixed and reloaded."
    case .reloadKeptPreviousConfig:
      return
        "The previous working config is still active. Fix the file and reload config to apply the changes."
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label(title, systemImage: "exclamationmark.triangle.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.primary)

      Text(summary)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)

      VStack(alignment: .leading, spacing: 6) {
        Text("Config file")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)

        Text(configPath)
          .font(.system(size: 12, design: .monospaced))
          .textSelection(.enabled)
      }

      if let issuePathText {
        VStack(alignment: .leading, spacing: 6) {
          Text("Config key")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)

          Text(issuePathText)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("What is wrong")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)

        ScrollView {
          Text(detailText)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
        }
        .frame(minHeight: 120, maxHeight: 220)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
      }

      HStack {
        Button("Open Config") {
          openConfig()
        }

        Spacer()

        Button("Close", action: onClose)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(18)
    .frame(width: 560)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
  }

  private func normalizedText(_ value: String) -> String {
    value
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private func openConfig() {
    let url = URL(fileURLWithPath: configPath)
    NSWorkspace.shared.open(url)
  }
}
