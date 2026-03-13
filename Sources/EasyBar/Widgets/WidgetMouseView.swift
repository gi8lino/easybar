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
        EventBus.shared.emitWidgetEvent("mouse.entered", widgetID: widgetID)
    }

    override func mouseExited(with event: NSEvent) {
        EventBus.shared.emitWidgetEvent("mouse.exited", widgetID: widgetID)
    }

    override func mouseDown(with event: NSEvent) {
        EventBus.shared.emitWidgetEvent("mouse.down", widgetID: widgetID, data: [
            "button": "left"
        ])
    }

    override func mouseUp(with event: NSEvent) {
        EventBus.shared.emitWidgetEvent("mouse.up", widgetID: widgetID, data: [
            "button": "left"
        ])
        EventBus.shared.emitWidgetEvent("mouse.clicked", widgetID: widgetID, data: [
            "button": "left"
        ])
    }

    override func rightMouseDown(with event: NSEvent) {
        EventBus.shared.emitWidgetEvent("mouse.down", widgetID: widgetID, data: [
            "button": "right"
        ])
    }

    override func rightMouseUp(with event: NSEvent) {
        EventBus.shared.emitWidgetEvent("mouse.up", widgetID: widgetID, data: [
            "button": "right"
        ])
        EventBus.shared.emitWidgetEvent("mouse.clicked", widgetID: widgetID, data: [
            "button": "right"
        ])
    }

    override func otherMouseDown(with event: NSEvent) {
        EventBus.shared.emitWidgetEvent("mouse.down", widgetID: widgetID, data: [
            "button": "middle"
        ])
    }

    override func otherMouseUp(with event: NSEvent) {
        EventBus.shared.emitWidgetEvent("mouse.up", widgetID: widgetID, data: [
            "button": "middle"
        ])
        EventBus.shared.emitWidgetEvent("mouse.clicked", widgetID: widgetID, data: [
            "button": "middle"
        ])
    }

    override func scrollWheel(with event: NSEvent) {
        let direction = event.scrollingDeltaY > 0 ? "up" : "down"

        EventBus.shared.emitWidgetEvent("mouse.scrolled", widgetID: widgetID, data: [
            "direction": direction,
            "delta_x": String(describing: Double(event.scrollingDeltaX)),
            "delta_y": String(describing: Double(event.scrollingDeltaY))
        ])
    }
}
