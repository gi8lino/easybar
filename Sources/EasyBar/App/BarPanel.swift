import AppKit

/// Borderless non-activating panel used for the EasyBar window.
final class BarPanel: NSPanel {
  var contextMenuProvider: ((Bool) -> NSMenu)?

  override var canBecomeKey: Bool {
    false
  }

  override var canBecomeMain: Bool {
    false
  }

  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
    frameRect
  }

  /// Shows the dynamic bar context menu on right click.
  override func rightMouseUp(with event: NSEvent) {
    let showDeveloperSection = event.modifierFlags.contains(.shift)

    guard let menu = contextMenuProvider?(showDeveloperSection) else {
      super.rightMouseUp(with: event)
      return
    }

    guard let targetView = contentView else {
      super.rightMouseUp(with: event)
      return
    }

    NSMenu.popUpContextMenu(menu, with: event, for: targetView)
  }
}
