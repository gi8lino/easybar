import SwiftUI
import AppKit

struct PopupHoverRegion: NSViewRepresentable {

    let onHoverChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onHoverChanged: onHoverChanged)
    }

    func makeNSView(context: Context) -> PopupHoverNSView {
        let view = PopupHoverNSView()
        view.hoverChanged = context.coordinator.onHoverChanged
        return view
    }

    func updateNSView(_ nsView: PopupHoverNSView, context: Context) {
        nsView.hoverChanged = context.coordinator.onHoverChanged
    }

    final class Coordinator {
        let onHoverChanged: (Bool) -> Void

        init(onHoverChanged: @escaping (Bool) -> Void) {
            self.onHoverChanged = onHoverChanged
        }
    }
}

final class PopupHoverNSView: NSView {

    var hoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]

        let area = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        hoverChanged?(false)
    }
}
