import EasyBarShared
import Foundation

/// Labels used to describe where app events originated before they reach EventHub.
enum EventSourceLabel {
  static let runtimeManualRefresh = "runtime manual_refresh"

  static func script(_ command: IPC.Command) -> String {
    "script \(command.rawValue)"
  }

  static func aerospaceSubscribe(_ eventName: String) -> String {
    "aerospace subscribe \(eventName)"
  }
}
