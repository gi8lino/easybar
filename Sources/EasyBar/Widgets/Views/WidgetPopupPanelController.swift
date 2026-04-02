import AppKit
import SwiftUI

/// Manages one AppKit popup panel anchored to a widget view.
final class WidgetPopupPanelController: ObservableObject {
  private weak var anchorView: NSView?
  private weak var parentWindow: NSWindow?
  private var panel: NSPanel?
  private var hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  private var isPresented = false
  private var parentWindowObservers: [NSObjectProtocol] = []

  deinit {
    removeParentWindowObservers()
  }

  /// Stores the current anchor view.
  func updateAnchorView(_ view: NSView) {
    let nextWindow = view.window
    if parentWindow !== nextWindow {
      detachFromParentWindow()
      parentWindow = nextWindow
      installParentWindowObservers()
    }

    anchorView = view
    refreshPresentation()
  }

  /// Updates the popup content and presentation state.
  func update(isPresented: Bool, content: AnyView) {
    self.isPresented = isPresented
    hostingController.rootView = content
    refreshPresentation()
  }

  /// Closes the popup when present.
  func close() {
    guard let panel else { return }

    detachFromParentWindow()
    panel.orderOut(nil)
  }

  /// Applies the current presentation state to the panel.
  private func refreshPresentation() {
    guard isPresented else {
      close()
      return
    }

    showIfPossible()
  }

  /// Shows or repositions the popup when the anchor and parent window are ready.
  private func showIfPossible() {
    guard let anchorView else { return }
    guard let parentWindow = anchorView.window ?? parentWindow else { return }
    guard anchorView.window != nil else {
      close()
      return
    }
    guard !anchorView.bounds.isEmpty else {
      close()
      return
    }

    let panel = panel ?? makePanel()
    self.panel = panel
    if self.parentWindow !== parentWindow {
      detachFromParentWindow()
      self.parentWindow = parentWindow
      installParentWindowObservers()
    }

    let anchorRect = anchorView.convert(anchorView.bounds, to: nil)
    let screenRect = parentWindow.convertToScreen(anchorRect)

    hostingController.view.layoutSubtreeIfNeeded()
    let contentSize = hostingController.view.fittingSize
    guard contentSize.width > 0, contentSize.height > 0 else { return }

    panel.setContentSize(contentSize)
    panel.setFrameOrigin(
      NSPoint(
        x: screenRect.maxX - contentSize.width,
        y: screenRect.minY - contentSize.height - 6
      ))

    if panel.parent == nil {
      parentWindow.addChildWindow(panel, ordered: .above)
    }

    panel.orderFront(nil)
  }

  /// Builds the shared popup panel instance.
  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.contentViewController = hostingController
    return panel
  }

  /// Detaches the popup panel from the current parent window.
  private func detachFromParentWindow() {
    guard let panel, let parentWindow else { return }
    parentWindow.removeChildWindow(panel)
  }

  /// Installs window observers used to keep the popup positioned correctly.
  private func installParentWindowObservers() {
    removeParentWindowObservers()

    guard let parentWindow else { return }
    let center = NotificationCenter.default
    let names: [Notification.Name] = [
      NSWindow.didMoveNotification,
      NSWindow.didResizeNotification,
      NSWindow.didChangeScreenNotification,
      NSWindow.willCloseNotification,
    ]

    parentWindowObservers = names.map { name in
      center.addObserver(forName: name, object: parentWindow, queue: .main) { [weak self] _ in
        self?.handleParentWindowUpdate(notification: name)
      }
    }
  }

  /// Removes any installed parent-window observers.
  private func removeParentWindowObservers() {
    let center = NotificationCenter.default
    parentWindowObservers.forEach(center.removeObserver)
    parentWindowObservers.removeAll()
  }

  /// Handles one relevant parent-window lifecycle update.
  private func handleParentWindowUpdate(notification: Notification.Name) {
    if notification == NSWindow.willCloseNotification {
      close()
      parentWindow = nil
      removeParentWindowObservers()
      return
    }

    refreshPresentation()
  }
}

/// Resolves the backing AppKit anchor view for popup positioning.
struct WidgetPopupAnchorView: NSViewRepresentable {
  let onResolve: (NSView) -> Void

  /// Creates the anchor view and reports it once attached.
  func makeNSView(context: Context) -> AnchorView {
    let view = AnchorView()
    view.onUpdate = onResolve
    return view
  }

  /// Updates the anchor callback and reports the current view.
  func updateNSView(_ nsView: AnchorView, context: Context) {
    nsView.onUpdate = onResolve
    onResolve(nsView)
  }
}

final class AnchorView: NSView {
  var onUpdate: ((NSView) -> Void)?

  /// Reports anchor updates after joining a window.
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    onUpdate?(self)
  }

  /// Reports anchor updates after layout changes.
  override func layout() {
    super.layout()
    onUpdate?(self)
  }
}
