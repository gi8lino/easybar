import AppKit
import SwiftUI

final class ConfigErrorWindowController: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var hostingController = NSHostingController(rootView: AnyView(EmptyView()))

  func present(failureState: Config.LoadFailureState, configPath: String) {
    hostingController.rootView = AnyView(
      ConfigErrorView(
        state: failureState,
        configPath: configPath,
        onClose: { [weak self] in
          self?.close()
        }
      )
    )

    let window = window ?? makeWindow()
    self.window = window

    hostingController.view.layoutSubtreeIfNeeded()
    let fittingSize = hostingController.view.fittingSize
    guard fittingSize.width > 0, fittingSize.height > 0 else { return }

    window.setContentSize(fittingSize)
    center(window: window, size: fittingSize)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    window?.close()
    reset()
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "EasyBar Config Error"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.level = .floating
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

  private func center(window: NSWindow, size: CGSize) {
    if let parentWindow = NSApp.keyWindow ?? NSApp.mainWindow {
      let parentFrame = parentWindow.frame
      window.setFrameOrigin(
        NSPoint(
          x: parentFrame.midX - size.width / 2,
          y: parentFrame.midY - size.height / 2
        )
      )
      return
    }

    if let screenFrame = NSScreen.main?.visibleFrame {
      window.setFrameOrigin(
        NSPoint(
          x: screenFrame.midX - size.width / 2,
          y: screenFrame.midY - size.height / 2
        )
      )
    }
  }

  private func reset() {
    window = nil
    hostingController = NSHostingController(rootView: AnyView(EmptyView()))
  }

  func windowWillClose(_ notification: Notification) {
    reset()
  }
}
