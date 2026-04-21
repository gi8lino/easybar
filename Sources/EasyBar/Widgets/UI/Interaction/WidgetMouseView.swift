import AppKit
import SwiftUI

/// AppKit-backed event surface for widget mouse input.
struct WidgetMouseView: NSViewRepresentable {
  let widgetID: String
  let targetWidgetID: String
  let tracksHover: Bool
  let emitsMouseHover: Bool
  let emitsMouseDown: Bool
  let emitsMouseUp: Bool
  let emitsMouseClick: Bool
  let emitsMouseScroll: Bool
  let onHoverChanged: ((Bool) -> Void)?

  init(
    widgetID: String,
    targetWidgetID: String? = nil,
    tracksHover: Bool = true,
    emitsMouseHover: Bool = false,
    emitsMouseDown: Bool = false,
    emitsMouseUp: Bool = false,
    emitsMouseClick: Bool = false,
    emitsMouseScroll: Bool = false,
    onHoverChanged: ((Bool) -> Void)? = nil
  ) {
    self.widgetID = widgetID
    self.targetWidgetID = targetWidgetID ?? widgetID
    self.tracksHover = tracksHover
    self.emitsMouseHover = emitsMouseHover
    self.emitsMouseDown = emitsMouseDown
    self.emitsMouseUp = emitsMouseUp
    self.emitsMouseClick = emitsMouseClick
    self.emitsMouseScroll = emitsMouseScroll
    self.onHoverChanged = onHoverChanged
  }

  /// Creates the AppKit-backed mouse surface.
  func makeNSView(context: Context) -> MouseTrackingNSView {
    let view = MouseTrackingNSView()
    view.widgetID = widgetID
    view.targetWidgetID = targetWidgetID
    view.tracksHover = tracksHover
    view.emitsMouseHover = emitsMouseHover
    view.emitsMouseDown = emitsMouseDown
    view.emitsMouseUp = emitsMouseUp
    view.emitsMouseClick = emitsMouseClick
    view.emitsMouseScroll = emitsMouseScroll
    view.onHoverChanged = onHoverChanged
    return view
  }

  /// Updates the AppKit surface ids and interaction flags.
  func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
    nsView.widgetID = widgetID
    nsView.targetWidgetID = targetWidgetID
    nsView.tracksHover = tracksHover
    nsView.emitsMouseHover = emitsMouseHover
    nsView.emitsMouseDown = emitsMouseDown
    nsView.emitsMouseUp = emitsMouseUp
    nsView.emitsMouseClick = emitsMouseClick
    nsView.emitsMouseScroll = emitsMouseScroll
    nsView.onHoverChanged = onHoverChanged
  }
}

final class MouseTrackingNSView: NSView {
  var widgetID: String = ""
  var targetWidgetID: String = ""
  var tracksHover = true
  var emitsMouseHover = false
  var emitsMouseDown = false
  var emitsMouseUp = false
  var emitsMouseClick = false
  var emitsMouseScroll = false
  var onHoverChanged: ((Bool) -> Void)?

  private var trackingArea: NSTrackingArea?
  private var isMouseInside = false
  private static let hoverState = HoverState()

  /// Accept the first click even when EasyBar is not active.
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  /// Keep the view eligible for responder handling.
  override var acceptsFirstResponder: Bool {
    true
  }

  /// Make this transparent view participate in hit-testing only when it actually needs to
  /// consume button or scroll events. Hover tracking uses `NSTrackingArea` and does not need
  /// to win hit-testing.
  override func hitTest(_ point: NSPoint) -> NSView? {
    guard bounds.contains(point) else { return nil }
    return handlesDirectMouseEvents ? self : nil
  }

  /// Returns whether this surface needs direct event ownership.
  private var handlesDirectMouseEvents: Bool {
    emitsMouseDown || emitsMouseUp || emitsMouseClick || emitsMouseScroll
  }

  /// Rebuilds tracking areas after layout updates.
  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    replaceTrackingArea()
  }

  /// Emits hover-entered when tracking is enabled.
  override func mouseEntered(with event: NSEvent) {
    guard tracksHover else { return }
    guard !isMouseInside else { return }
    isMouseInside = true
    guard Self.hoverState.enter(widgetID: targetWidgetID) else { return }

    onHoverChanged?(true)

    if emitsMouseHover {
      emitMouseEvent(.mouseEntered)
    }
  }

  /// Emits hover-exited when tracking is enabled.
  override func mouseExited(with event: NSEvent) {
    guard tracksHover else { return }
    guard isMouseInside else { return }
    isMouseInside = false

    Self.hoverState.exit(widgetID: self.targetWidgetID) { [weak self] in
      guard let self else { return }

      self.onHoverChanged?(false)

      if self.emitsMouseHover {
        self.emitMouseEvent(.mouseExited)
      }
    }
  }

  /// Emits a left-button mouse-down event.
  override func mouseDown(with event: NSEvent) {
    emitMouseDown(button: .left)
  }

  /// Emits a left-button mouse-up and clicked event.
  override func mouseUp(with event: NSEvent) {
    emitMouseUp(button: .left)
  }

  /// Emits a right-button mouse-down event.
  override func rightMouseDown(with event: NSEvent) {
    emitMouseDown(button: .right)
  }

  /// Emits a right-button mouse-up and clicked event.
  override func rightMouseUp(with event: NSEvent) {
    emitMouseUp(button: .right)
  }

  /// Emits a middle-button mouse-down event.
  override func otherMouseDown(with event: NSEvent) {
    emitMouseDown(button: .middle)
  }

  /// Emits a middle-button mouse-up and clicked event.
  override func otherMouseUp(with event: NSEvent) {
    emitMouseUp(button: .middle)
  }

  /// Emits one scroll-wheel event.
  override func scrollWheel(with event: NSEvent) {
    guard emitsMouseScroll else { return }

    let direction: ScrollDirection = event.scrollingDeltaY > 0 ? .up : .down

    easybarLog.debug("mouse scrolled widget=\(widgetID) direction=\(direction.rawValue)")

    Task {
      await EventHub.shared.emitWidgetEvent(
        .mouseScrolled,
        widgetID: widgetID,
        targetWidgetID: targetWidgetID,
        direction: direction,
        deltaX: Double(event.scrollingDeltaX),
        deltaY: Double(event.scrollingDeltaY)
      )
    }
  }

  /// Replaces the current tracking area with the standard widget mouse options.
  private func replaceTrackingArea() {
    removeTrackingAreaIfNeeded()
    guard tracksHover else { return }

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

  /// Returns the tracking options used for widget mouse handling.
  private var trackingOptions: NSTrackingArea.Options {
    [
      .mouseEnteredAndExited,
      .mouseMoved,
      .activeAlways,
      .inVisibleRect,
    ]
  }

  /// Emits one mouse down event for the given button.
  private func emitMouseDown(button: MouseButton) {
    guard emitsMouseDown else { return }
    emitMouseEvent(.mouseDown, button: button)
  }

  /// Emits one mouse up and click pair for the given button.
  private func emitMouseUp(button: MouseButton) {
    if emitsMouseUp {
      emitMouseEvent(.mouseUp, button: button)
    }

    if emitsMouseClick {
      emitMouseEvent(.mouseClicked, button: button)
    }
  }

  /// Emits one widget mouse event with shared logging.
  private func emitMouseEvent(_ event: WidgetEvent, button: MouseButton? = nil) {
    let buttonSuffix = button.map { " button=\($0.rawValue)" } ?? ""
    easybarLog.debug(
      "event=\(event.rawValue) widget=\(widgetID) target=\(targetWidgetID)\(buttonSuffix)"
    )

    Task {
      await EventHub.shared.emitWidgetEvent(
        event,
        widgetID: widgetID,
        targetWidgetID: targetWidgetID,
        button: button
      )
    }
  }
}

private final class HoverState {
  private let lock = NSLock()
  private var hoveredWidgetIDs = Set<String>()
  private var pendingExitWorkItems: [String: DispatchWorkItem] = [:]

  /// Marks one widget as hovered and returns whether it was newly entered.
  func enter(widgetID: String) -> Bool {
    lock.lock()
    defer { lock.unlock() }

    pendingExitWorkItems[widgetID]?.cancel()
    pendingExitWorkItems[widgetID] = nil

    let inserted = hoveredWidgetIDs.insert(widgetID).inserted
    return inserted
  }

  /// Delays the hover-exit slightly so overlapping surfaces do not flicker.
  func exit(widgetID: String, handler: @escaping () -> Void) {
    lock.lock()
    pendingExitWorkItems[widgetID]?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }

      self.lock.lock()
      let removed = self.hoveredWidgetIDs.remove(widgetID) != nil
      self.pendingExitWorkItems[widgetID] = nil
      self.lock.unlock()

      guard removed else { return }
      handler()
    }

    pendingExitWorkItems[widgetID] = workItem
    lock.unlock()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
  }
}
