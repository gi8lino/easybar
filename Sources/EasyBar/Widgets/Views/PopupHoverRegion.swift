import AppKit
import SwiftUI

struct PopupHoverRegion: NSViewRepresentable {

  let onHoverChanged: (Bool) -> Void

  /// Creates the coordinator that forwards hover changes.
  func makeCoordinator() -> Coordinator {
    Coordinator(onHoverChanged: onHoverChanged)
  }

  /// Creates the AppKit hover region.
  func makeNSView(context: Context) -> PopupHoverNSView {
    let view = PopupHoverNSView()
    view.hoverChanged = context.coordinator.onHoverChanged
    return view
  }

  /// Updates the AppKit hover callback.
  func updateNSView(_ nsView: PopupHoverNSView, context: Context) {
    nsView.hoverChanged = context.coordinator.onHoverChanged
  }

  final class Coordinator {
    let onHoverChanged: (Bool) -> Void

    /// Stores the hover callback for the representable.
    init(onHoverChanged: @escaping (Bool) -> Void) {
      self.onHoverChanged = onHoverChanged
    }
  }
}

final class PopupHoverNSView: NSView {

  var hoverChanged: ((Bool) -> Void)?
  private var trackingArea: NSTrackingArea?

  /// Keep this view out of hit-testing so it never steals clicks or scroll events.
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  /// Rebuilds tracking areas after bounds changes.
  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    replaceTrackingArea()
  }

  /// Emits hover-entered to SwiftUI.
  override func mouseEntered(with event: NSEvent) {
    hoverChanged?(true)
  }

  /// Emits hover-exited to SwiftUI.
  override func mouseExited(with event: NSEvent) {
    hoverChanged?(false)
  }

  /// Replaces the current tracking area with the standard hover configuration.
  private func replaceTrackingArea() {
    removeTrackingAreaIfNeeded()

    let area = NSTrackingArea(
      rect: .zero,
      options: trackingOptions,
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    trackingArea = area
  }

  /// Removes the current tracking area when present.
  private func removeTrackingAreaIfNeeded() {
    guard let trackingArea else { return }
    removeTrackingArea(trackingArea)
  }

  /// Returns the hover tracking options used by the popup region.
  private var trackingOptions: NSTrackingArea.Options {
    [
      .mouseEnteredAndExited,
      .activeAlways,
      .inVisibleRect,
    ]
  }
}
