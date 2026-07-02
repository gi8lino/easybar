import Foundation

/// Centralizes intentionally detached tasks.
///
/// Use this only for work that must not inherit the caller's actor, such as
/// blocking file-descriptor reads, socket accepts, or synchronous helper
/// process calls. Prefer `Task {}` for ordinary async follow-up work.
public enum DetachedTask {
  /// Runs one intentionally detached `Void` operation.
  @discardableResult
  public static func run(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never> {
    Task.detached(priority: priority) {
      await operation()
    }
  }
}
