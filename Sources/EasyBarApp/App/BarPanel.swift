import AppKit

/// Borderless non-activating panel used for the EasyBar window.
final class BarPanel: NSPanel {
  /// Builds the right-click menu, optionally including developer actions.
  var contextMenuProvider: ((Bool) -> NSMenu)?

  /// Prevents the bar panel from becoming key.
  override var canBecomeKey: Bool {
    false
  }

  /// Prevents the bar panel from becoming the main window.
  override var canBecomeMain: Bool {
    false
  }

  /// Allows the bar to keep its configured frame.
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
