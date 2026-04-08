import Foundation

protocol NativeWidget: AnyObject {
  var rootID: String { get }
  var appEventSubscriptions: Set<String> { get }
  func start()
  func stop()
  func reload()
}

extension NativeWidget {
  var appEventSubscriptions: Set<String> {
    []
  }

  func reload() {
    stop()
    start()
  }
}
