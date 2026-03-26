import Foundation

protocol NativeWidget: AnyObject {
  var rootID: String { get }
  func start()
  func stop()
  func reload()
}

extension NativeWidget {
  func reload() {
    stop()
    start()
  }
}
