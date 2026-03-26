import SwiftUI
import AppKit

/// AppKit-backed event surface for widget mouse input.
struct WidgetMouseView: NSViewRepresentable {

    let widgetID: String
    let tracksHover: Bool

    init(widgetID: String, tracksHover: Bool = true) {
        self.widgetID = widgetID
        self.tracksHover = tracksHover
    }

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView()
        view.widgetID = widgetID
        view.tracksHover = tracksHover
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        nsView.widgetID = widgetID
        nsView.tracksHover = tracksHover
    }
}

final class MouseTrackingNSView: NSView {

    var widgetID: String = ""
    var tracksHover = true

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

    /// Make this transparent view participate in hit-testing.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        return bounds.contains(localPoint) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        replaceTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        guard tracksHover else { return }
        guard !isMouseInside else { return }
        isMouseInside = true
        guard Self.hoverState.enter(widgetID: widgetID) else { return }
        Logger.debug("mouse entered widget=\(widgetID)")
        EventBus.shared.emitWidgetEvent(.mouseEntered, widgetID: widgetID)
    }

    override func mouseExited(with event: NSEvent) {
        guard tracksHover else { return }
        guard isMouseInside else { return }
        isMouseInside = false
        Self.hoverState.exit(widgetID: widgetID) {
            Logger.debug("mouse exited widget=\(self.widgetID)")
            EventBus.shared.emitWidgetEvent(.mouseExited, widgetID: self.widgetID)
        }
    }

    override func mouseDown(with event: NSEvent) {
        emitMouseDown(button: .left)
    }

    override func mouseUp(with event: NSEvent) {
        emitMouseUp(button: .left)
    }

    override func rightMouseDown(with event: NSEvent) {
        emitMouseDown(button: .right)
    }

    override func rightMouseUp(with event: NSEvent) {
        emitMouseUp(button: .right)
    }

    override func otherMouseDown(with event: NSEvent) {
        emitMouseDown(button: .middle)
    }

    override func otherMouseUp(with event: NSEvent) {
        emitMouseUp(button: .middle)
    }

    override func scrollWheel(with event: NSEvent) {
        let direction: ScrollDirection = event.scrollingDeltaY > 0 ? .up : .down

        Logger.debug("mouse scrolled widget=\(widgetID) direction=\(direction.rawValue)")

        EventBus.shared.emitWidgetEvent(
            .mouseScrolled,
            widgetID: widgetID,
            direction: direction,
            deltaX: Double(event.scrollingDeltaX),
            deltaY: Double(event.scrollingDeltaY)
        )
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
            .inVisibleRect
        ]
    }

    /// Emits one mouse down event for the given button.
    private func emitMouseDown(button: MouseButton) {
        Logger.debug("mouse down widget=\(widgetID) button=\(button.rawValue)")
        EventBus.shared.emitWidgetEvent(.mouseDown, widgetID: widgetID, button: button)
    }

    /// Emits one mouse up and click pair for the given button.
    private func emitMouseUp(button: MouseButton) {
        Logger.debug("mouse up widget=\(widgetID) button=\(button.rawValue)")
        Logger.debug("mouse clicked widget=\(widgetID) button=\(button.rawValue)")

        EventBus.shared.emitWidgetEvent(.mouseUp, widgetID: widgetID, button: button)
        EventBus.shared.emitWidgetEvent(.mouseClicked, widgetID: widgetID, button: button)
    }
}

private final class HoverState {

    private let lock = NSLock()
    private var hoveredWidgetIDs = Set<String>()
    private var pendingExitWorkItems: [String: DispatchWorkItem] = [:]

    func enter(widgetID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        pendingExitWorkItems[widgetID]?.cancel()
        pendingExitWorkItems[widgetID] = nil

        let inserted = hoveredWidgetIDs.insert(widgetID).inserted
        return inserted
    }

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
