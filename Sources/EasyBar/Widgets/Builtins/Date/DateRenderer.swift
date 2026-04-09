import Foundation

struct DateRenderer: NativeWidgetRenderer {

  typealias Snapshot = Date

  let rootID: String
  let config: Config.DateBuiltinConfig

  func makeNodes(snapshot: Date) -> [WidgetNodeState] {
    let formatter = DateFormatter()
    formatter.dateFormat = config.format

    return [
      BuiltinNativeNodeFactory.makeItemNode(
        rootID: rootID,
        placement: config.placement,
        style: config.style,
        text: formatter.string(from: snapshot)
      )
    ]
  }
}
