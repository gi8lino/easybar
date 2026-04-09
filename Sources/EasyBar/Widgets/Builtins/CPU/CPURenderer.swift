import Foundation

struct CPURenderer: NativeWidgetRenderer {

  typealias Snapshot = CPUSparklineNativeWidget.Snapshot

  let rootID: String

  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    [
      BuiltinNativeNodeFactory.makeSparklineNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style,
        text: snapshot.label,
        values: snapshot.samples,
        lineWidth: snapshot.lineWidth,
        color: snapshot.colorHex
      )
    ]
  }
}
