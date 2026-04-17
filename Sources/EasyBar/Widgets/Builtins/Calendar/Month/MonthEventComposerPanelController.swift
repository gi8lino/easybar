import AppKit
import SwiftUI

/// Manages a floating panel for the month-calendar event composer.
@MainActor
final class MonthCalendarEventComposerPanelController: ObservableObject {
  private var panel: NSPanel?
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

  /// Closes the composer panel when present.
  func close() {
    panel?.close()
    panel = nil
    composer = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }

  /// Shows the panel centered relative to the active window or screen.
  private func showIfPossible() {
    let panel = panel ?? makePanel()
    self.panel = panel

    if let composer {
      panel.title = composer.panelTitle
    }

    hostingController.view.layoutSubtreeIfNeeded()
    let fittingSize = hostingController.view.fittingSize
    guard fittingSize.width > 0, fittingSize.height > 0 else { return }

    panel.setContentSize(fittingSize)

    if let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow {
      let parentFrame = parentWindow.frame
      panel.setFrameOrigin(
        NSPoint(
          x: parentFrame.midX - fittingSize.width / 2,
          y: parentFrame.midY - fittingSize.height / 2
        )
      )
    } else if let screenFrame = NSScreen.main?.visibleFrame {
      panel.setFrameOrigin(
        NSPoint(
          x: screenFrame.midX - fittingSize.width / 2,
          y: screenFrame.midY - fittingSize.height / 2
        )
      )
    }

    panel.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Builds the shared floating composer panel.
  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: .zero,
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.title = "Appointment"
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.contentViewController = hostingController

    panel.standardWindowButton(.closeButton)?.isHidden = true
    panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
    panel.standardWindowButton(.zoomButton)?.isHidden = true

    return panel
  }
}
