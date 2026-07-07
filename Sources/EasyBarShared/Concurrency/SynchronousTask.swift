import Dispatch
import Foundation

/// Bridges explicitly chosen async or actor-isolated work back to synchronous callers.
///
/// Use this only at process-boundary edges that are already running on a dedicated
/// blocking thread, such as Unix-socket client threads. Do not call it from a
/// cooperative Swift task that could be needed to run the awaited operation.
public enum SynchronousTask {
  /// Runs one async operation and blocks the current thread until it returns.
  public static func run<T>(_ operation: @escaping () async -> T) -> T {
    let result = LockedState<T?>(nil)
    let semaphore = DispatchSemaphore(value: 0)

    Task {
      let value = await operation()
      result.withLock { state in
        state = value
      }
      semaphore.signal()
    }

    semaphore.wait()

    return result.withLock { state in
      guard let state else {
        preconditionFailure("SynchronousTask finished without a result")
      }
      return state
    }
  }

  /// Runs one MainActor-isolated operation and blocks the current thread until it returns.
  public static func runOnMainActor<T>(_ operation: @escaping @MainActor () -> T) -> T {
    run {
      await MainActor.run {
        operation()
      }
    }
  }
}
