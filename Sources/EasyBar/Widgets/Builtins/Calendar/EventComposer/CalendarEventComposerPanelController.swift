import AppKit
import Combine
import EasyBarCalendarUI
import EasyBarShared
import SwiftUI

/// Manages a floating panel for the shared calendar event composer.
@MainActor
final class CalendarEventComposerPanelController: ObservableObject {
  private enum SnapshotSource {
    case month
    case upcoming
  }

  private var panel: NSPanel?
  private var hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  private var composer: CalendarEventComposer?

  /// Presents the composer panel for one new appointment.
  func present(
    defaultDate: Date,
    onChanged: @escaping () -> Void
  ) {
    let composer = makeComposer(snapshotSource: .month)
    composer.prepare(defaultDate: defaultDate)
    self.composer = composer

    hostingController.rootView = AnyView(
      CalendarEventComposerView(
        composer: composer,
        config: Config.shared.builtinCalendar.calendarComposerUIConfig,
        appointmentsStyle: Config.shared.builtinCalendar.appointmentsCalendarUIStyle,
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
    event: CalendarAgentEvent,
    onChanged: @escaping () -> Void
  ) {
    let composer = makeComposer(snapshotSource: .upcoming)
    composer.prepare(event: event)
    self.composer = composer

    hostingController.rootView = AnyView(
      CalendarEventComposerView(
        composer: composer,
        config: Config.shared.builtinCalendar.calendarComposerUIConfig,
        appointmentsStyle: Config.shared.builtinCalendar.appointmentsCalendarUIStyle,
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

  /// Builds one reusable composer view model wired to EasyBar stores and agent clients.
  private func makeComposer(snapshotSource: SnapshotSource) -> CalendarEventComposer {
    let snapshotPublisher: AnyPublisher<CalendarAgentSnapshot?, Never>
    let refreshSnapshots: () -> Void

    switch snapshotSource {
    case .month:
      snapshotPublisher = NativeMonthCalendarStore.shared.$snapshot.eraseToAnyPublisher()
      refreshSnapshots = {
        MonthCalendarAgentClient.shared.refresh()
      }
    case .upcoming:
      snapshotPublisher = NativeUpcomingCalendarStore.shared.$snapshot.eraseToAnyPublisher()
      refreshSnapshots = {
        UpcomingCalendarAgentClient.shared.refresh()
      }
    }

    return CalendarEventComposer(
      config: Config.shared.builtinCalendar.calendarComposerUIConfig,
      snapshotPublisher: snapshotPublisher,
      refreshSnapshots: refreshSnapshots,
      createEvent: { event, completion in
        MonthCalendarAgentClient.shared.createEvent(event, completion: completion)
      },
      updateEvent: { event, completion in
        MonthCalendarAgentClient.shared.updateEvent(event, completion: completion)
      },
      deleteEvent: { event, completion in
        MonthCalendarAgentClient.shared.deleteEvent(event, completion: completion)
      },
      openCalendarApp: {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal")
        else { return }
        NSWorkspace.shared.open(appURL)
      }
    )
  }
}
