import AppKit
import SwiftUI

/// Manages a standalone window for the month-calendar event composer.
@MainActor
final class MonthCalendarEventComposerPanelController: NSObject, ObservableObject, NSWindowDelegate {
  private var window: NSWindow?
  private var hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  private var composer: MonthCalendarEventComposer?

  /// Presents the composer panel for one new appointment.
  func present(
    defaultDate: Date,
    onChanged: @escaping () -> Void
  ) {
    let composer = MonthCalendarEventComposer()
    composer.prepare(defaultDate: defaultDate)
    self.composer = composer

    hostingController.rootView = AnyView(
      MonthCalendarEventComposerView(
        composer: composer,
        onCancel: { [weak self] in
          self?.close()
        },
        onSaved: { [weak self] in
          onChanged()
          self?.close()
        },
        onDeleted: { [weak self] in
          onChanged()
          self?.close()
        }
      )
    )

    showIfPossible()
  }

  /// Presents the composer panel for one existing appointment.
  func present(
    event: NativeMonthCalendarEvent,
    onChanged: @escaping () -> Void
  ) {
    let composer = MonthCalendarEventComposer()
    composer.prepare(event: event)
    self.composer = composer

    hostingController.rootView = AnyView(
      MonthCalendarEventComposerView(
        composer: composer,
        onCancel: { [weak self] in
          self?.close()
        },
        onSaved: { [weak self] in
          onChanged()
          self?.close()
        },
        onDeleted: { [weak self] in
          onChanged()
          self?.close()
        }
      )
    )

    showIfPossible()
  }

  /// Closes the composer window when present.
  func close() {
    window?.close()
    reset()
  }

  /// Shows the window centered relative to the active window or screen.
  private func showIfPossible() {
    let window = window ?? makeWindow()
    self.window = window

    if let composer {
      window.title = composer.panelTitle
    }

    hostingController.view.layoutSubtreeIfNeeded()
    let fittingSize = hostingController.view.fittingSize
    guard fittingSize.width > 0, fittingSize.height > 0 else { return }

    window.setContentSize(fittingSize)

    if let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow {
      let parentFrame = parentWindow.frame
      window.setFrameOrigin(
        NSPoint(
          x: parentFrame.midX - fittingSize.width / 2,
          y: parentFrame.midY - fittingSize.height / 2
        )
      )
    } else if let screenFrame = NSScreen.main?.visibleFrame {
      window.setFrameOrigin(
        NSPoint(
          x: screenFrame.midX - fittingSize.width / 2,
          y: screenFrame.midY - fittingSize.height / 2
        )
      )
    }

    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Builds the shared composer window.
  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "Appointment"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.level = .normal
    window.hasShadow = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    window.backgroundColor = .clear
    window.isOpaque = false
    window.representedURL = nil
    window.miniwindowImage = NSApp.applicationIconImage
    window.standardWindowButton(.documentIconButton)?.image = NSApp.applicationIconImage
    window.contentViewController = hostingController
    window.delegate = self

    window.standardWindowButton(.zoomButton)?.isHidden = true

    return window
  }

  /// Clears the retained composer-window state.
  private func reset() {
    window = nil
    composer = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }

  /// Clears retained state after the user closes the window directly.
  func windowWillClose(_ notification: Notification) {
    reset()
  }
}
