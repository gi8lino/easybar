import AppKit
import SwiftUI

/// Presents a floating window that explains config load or reload failures.
@MainActor
final class ConfigErrorWindowController: NSObject, NSWindowDelegate {
  /// Currently presented config error window.
  private var window: NSWindow?
  /// Hosting controller reused for the error content view.
  private var hostingController = NSHostingController(rootView: AnyView(EmptyView()))

  /// Presents the current config failure state in a dedicated floating window.
  func present(
    failureState: Config.LoadFailureState,
    configPath: String,
    onReload: @escaping () -> Void
  ) {
    hostingController.rootView = AnyView(
      ConfigErrorContentView(
        state: failureState,
        configPath: configPath,
        onReload: onReload,
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
    window = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }

  /// Builds the floating config error window shell.
  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: [.titled, .fullSizeContentView],
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
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.standardWindowButton(.documentIconButton)?.image = NSApp.applicationIconImage
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

  /// Resets controller state when the user closes the window directly.
  func windowWillClose(_ notification: Notification) {
    window = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }
}

/// SwiftUI content for config load and reload errors.
private struct ConfigErrorContentView: View {
  /// Failure state to explain to the user.
  let state: Config.LoadFailureState
  /// Path to the config file that failed.
  let configPath: String
  /// Callback used by the Reload button.
  let onReload: () -> Void
  /// Callback used by the Close button.
  let onClose: () -> Void

  /// Failure as a structured config error when available.
  private var configError: ConfigError? {
    return state.error as? ConfigError
  }

  /// Config key path or source location associated with the failure.
  private var issuePathText: String? {
    guard let configError else {
      return nil
    }

    let text = configError.configPath.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
  }

  /// Problem item/key associated with the failure.
  private var problemItemText: String? {
    guard let value = configError?.problemItem else {
      return nil
    }

    let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
  }

  /// Problem value associated with the failure.
  private var problemValueText: String? {
    guard let value = configError?.problemValue else {
      return nil
    }

    let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
  }

  /// Returns whether the problem metadata block should be shown.
  private var showsProblemBlock: Bool {
    return problemItemText != nil || problemValueText != nil
  }

  /// Detailed user-facing error text.
  private var detailText: String {
    if let configError {
      return configError.detail
    }

    return normalizedText(state.error.localizedDescription)
  }

  /// Window title text for the failure context.
  private var title: String {
    switch state.context {
    case .initialLoad:
      return "EasyBar started with a config problem"
    case .reloadKeptPreviousConfig:
      return "EasyBar could not apply the new config"
    }
  }

  /// Short explanation of the current fallback behavior.
  private var summary: String {
    switch state.context {
    case .initialLoad:
      return "The bar is running with fallback defaults until the config is fixed and reloaded."
    case .reloadKeptPreviousConfig:
      return
        "The previous working config is still active. Fix the file and reload config to apply the changes."
    }
  }

  /// Renders the error summary, details, and actions.
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
          Text("Config location")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)

          Text(issuePathText)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
        }
      }

      if showsProblemBlock {
        VStack(alignment: .leading, spacing: 6) {
          Text("Problem")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)

          VStack(alignment: .leading, spacing: 4) {
            if let problemItemText {
              HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("item:")
                  .foregroundStyle(.secondary)

                Text(problemItemText)
                  .textSelection(.enabled)
              }
            }

            if let problemValueText {
              HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("value:")
                  .foregroundStyle(.secondary)

                Text(problemValueText)
                  .textSelection(.enabled)
              }
            }
          }
          .font(.system(size: 12, design: .monospaced))
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
        .frame(minHeight: 90, maxHeight: 180)
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
        .keyboardShortcut("o", modifiers: [.command])

        Button("Reload Config", action: onReload)
          .keyboardShortcut("r", modifiers: [.command])

        Spacer()

        Button("Close", action: onClose)
          .keyboardShortcut(.cancelAction)
      }
    }
    .padding(18)
    .frame(width: 560)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor))
    )
  }

  /// Collapses whitespace in fallback error text.
  private func normalizedText(_ value: String) -> String {
    return
      value
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  /// Opens the config file in Finder or the default editor.
  private func openConfig() {
    let url = URL(fileURLWithPath: configPath)
    NSWorkspace.shared.open(url)
  }
}
