import Foundation

/// Main-actor observable holder for the active immutable config snapshot.
///
/// Runtime services receive explicit `ConfigSnapshot` values. SwiftUI views use this
/// store only to observe which immutable snapshot is currently active.
@MainActor
final class ConfigSnapshotStore: ObservableObject {
  /// Active config snapshot used by UI renderers.
  @Published private(set) var snapshot: ConfigSnapshot

  /// Creates a snapshot store with the provided initial snapshot.
  init(snapshot: ConfigSnapshot) {
    self.snapshot = snapshot
  }

  /// Replaces the active snapshot after a successful or rejected config load.
  func apply(_ snapshot: ConfigSnapshot) {
    self.snapshot = snapshot
  }
}
