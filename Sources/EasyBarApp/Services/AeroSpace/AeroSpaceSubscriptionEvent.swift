import Foundation

/// One event emitted by `aerospace subscribe`.
struct AeroSpaceSubscriptionEvent: Decodable, Equatable, Sendable {
  /// AeroSpace event names that affect EasyBar's AeroSpace-backed state.
  enum Name {
    static let focusChanged = "focus-changed"
    static let focusedWorkspaceChanged = "focused-workspace-changed"
    static let focusedMonitorChanged = "focused-monitor-changed"
    static let modeChanged = "mode-changed"
    static let windowDetected = "window-detected"
    static let bindingTriggered = "binding-triggered"
    static let unknown = "unknown"
  }

  /// Arguments for the long-lived AeroSpace event stream.
  ///
  /// `--all` keeps EasyBar aligned with AeroSpace's current event set, and the
  /// default initial send gives the app one immediate sync signal on connect.
  static let subscribeArguments = ["subscribe", "--all"]

  /// Human-readable subscription scope used in logs.
  static let subscriptionDescription = "all"

  /// Longer debounce for key bindings because AeroSpace emits `binding-triggered`
  /// before running the binding's commands.
  static let bindingTriggeredRefreshDelayNanoseconds: UInt64 = 150_000_000

  /// Raw AeroSpace event name.
  let name: String

  /// Creates one event with a raw AeroSpace event name.
  init(name: String) {
    self.name = name
  }

  /// Decodes one JSON-line event from AeroSpace.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
  }

  /// Delay to use before re-reading AeroSpace state.
  var refreshDelayNanoseconds: UInt64 {
    switch name {
    case Name.bindingTriggered:
      return Self.bindingTriggeredRefreshDelayNanoseconds
    default:
      return 0
    }
  }

  /// Matching EasyBar app event for Lua subscriptions, when available.
  var appEvent: AppEvent? {
    switch name {
    case Name.focusChanged:
      return .focusChange
    case Name.focusedWorkspaceChanged, Name.focusedMonitorChanged:
      return .workspaceChange
    default:
      return nil
    }
  }

  private enum CodingKeys: String, CodingKey {
    case name = "_event"
  }
}
