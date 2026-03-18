import SwiftUI
import AppKit

/// AppKit-backed event surface for widget mouse input.
struct WidgetMouseView: NSViewRepresentable {

    let widgetID: String

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let view = MouseTrackingNSView()
        view.widgetID = widgetID
        return view
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        nsView.widgetID = widgetID
    }
}

final class MouseTrackingNSView: NSView {

    var widgetID: String = ""

    private var trackingArea: NSTrackingArea?

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

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]

        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        Logger.debug("mouse entered widget=\(widgetID)")
        EventBus.shared.emitWidgetEvent(.mouseEntered, widgetID: widgetID)
    }

    override func mouseExited(with event: NSEvent) {
        Logger.debug("mouse exited widget=\(widgetID)")
        EventBus.shared.emitWidgetEvent(.mouseExited, widgetID: widgetID)
    }

    override func mouseDown(with event: NSEvent) {
        Logger.debug("mouse down widget=\(widgetID) button=left")
        EventBus.shared.emitWidgetEvent(.mouseDown, widgetID: widgetID, button: .left)
    }

    override func mouseUp(with event: NSEvent) {
        Logger.debug("mouse up widget=\(widgetID) button=left")
        Logger.debug("mouse clicked widget=\(widgetID) button=left")

        EventBus.shared.emitWidgetEvent(.mouseUp, widgetID: widgetID, button: .left)
        EventBus.shared.emitWidgetEvent(.mouseClicked, widgetID: widgetID, button: .left)
    }

    override func rightMouseDown(with event: NSEvent) {
        Logger.debug("mouse down widget=\(widgetID) button=right")
        EventBus.shared.emitWidgetEvent(.mouseDown, widgetID: widgetID, button: .right)
    }

    override func rightMouseUp(with event: NSEvent) {
        Logger.debug("mouse up widget=\(widgetID) button=right")
        Logger.debug("mouse clicked widget=\(widgetID) button=right")

        EventBus.shared.emitWidgetEvent(.mouseUp, widgetID: widgetID, button: .right)
        EventBus.shared.emitWidgetEvent(.mouseClicked, widgetID: widgetID, button: .right)
    }

    override func otherMouseDown(with event: NSEvent) {
        Logger.debug("mouse down widget=\(widgetID) button=middle")
        EventBus.shared.emitWidgetEvent(.mouseDown, widgetID: widgetID, button: .middle)
    }

    override func otherMouseUp(with event: NSEvent) {
        Logger.debug("mouse up widget=\(widgetID) button=middle")
        Logger.debug("mouse clicked widget=\(widgetID) button=middle")

        EventBus.shared.emitWidgetEvent(.mouseUp, widgetID: widgetID, button: .middle)
        EventBus.shared.emitWidgetEvent(.mouseClicked, widgetID: widgetID, button: .middle)
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
}
