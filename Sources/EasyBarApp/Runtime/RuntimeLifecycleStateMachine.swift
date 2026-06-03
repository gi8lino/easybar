import Foundation

/// Lifecycle operation that must be serialized by the runtime coordinator.
enum RuntimeLifecycleOperation: String {
  /// Reloads config and reapplies all dependent runtime state.
  case reloadConfig
  /// Restarts only the Lua/widget runtime.
  case restartLuaRuntime
}

/// Result of attempting to start runtime lifecycle ownership.
enum RuntimeLifecycleStartResult {
  /// The runtime was already started.
  case alreadyStarted
  /// Startup may proceed for the returned generation.
  case started(generation: UInt64)
}

/// Result of attempting to begin a serialized lifecycle operation.
enum RuntimeLifecycleBeginResult {
  /// The operation was queued because another operation is already running.
  case queued
  /// The operation may proceed for the returned generation.
  case started(generation: UInt64)
}

/// Small state machine that owns runtime lifecycle and reload/restart queue state.
struct RuntimeLifecycleStateMachine {
  /// Whether runtime services are currently started.
  private(set) var started = false
  /// Generation used to cancel stale lifecycle work.
  private(set) var generation: UInt64 = 0
  /// Whether a config reload is in progress.
  private var isReloadingConfig = false
  /// Whether a Lua runtime restart is in progress.
  private var isRestartingLuaRuntime = false
  /// Whether another config reload should run after current work.
  private var queuedConfigReload = false
  /// Whether another Lua restart should run after current work.
  private var queuedLuaRuntimeRestart = false

  /// Returns whether the runtime is currently busy with another lifecycle operation.
  private var isBusy: Bool {
    isReloadingConfig || isRestartingLuaRuntime
  }

  /// Starts the runtime lifecycle and returns the generation for startup work.
  mutating func start() -> RuntimeLifecycleStartResult {
    guard !started else { return .alreadyStarted }

    let generation = advanceGeneration()
    started = true
    return .started(generation: generation)
  }

  /// Stops the runtime lifecycle and clears all queued or in-flight work.
  mutating func stop() -> Bool {
    guard started else { return false }

    started = false
    _ = advanceGeneration()
    resetWork()
    return true
  }

  /// Begins one lifecycle operation or queues it when another operation is active.
  mutating func begin(_ operation: RuntimeLifecycleOperation) -> RuntimeLifecycleBeginResult {
    if isBusy {
      queue(operation)
      return .queued
    }

    markStarted(operation)
    return .started(generation: generation)
  }

  /// Returns whether startup work for the provided generation may still continue.
  func canContinueStartup(generation expectedGeneration: UInt64) -> Bool {
    started && generation == expectedGeneration
  }

  /// Returns whether lifecycle work for the provided generation may still continue.
  mutating func canContinueLifecycleWork(generation expectedGeneration: UInt64) -> Bool {
    guard started, generation == expectedGeneration else {
      if generation == expectedGeneration {
        resetWork()
      }

      return false
    }

    return true
  }

  /// Marks one lifecycle operation as finished and returns the next queued operation.
  mutating func finish(_ operation: RuntimeLifecycleOperation) -> RuntimeLifecycleOperation? {
    markFinished(operation)
    return dequeueNextOperation()
  }

  /// Advances the lifecycle generation and returns the new value.
  private mutating func advanceGeneration() -> UInt64 {
    generation &+= 1
    return generation
  }

  /// Queues the provided lifecycle operation.
  private mutating func queue(_ operation: RuntimeLifecycleOperation) {
    switch operation {
    case .reloadConfig:
      queuedConfigReload = true
    case .restartLuaRuntime:
      queuedLuaRuntimeRestart = true
    }
  }

  /// Marks one lifecycle operation as started.
  private mutating func markStarted(_ operation: RuntimeLifecycleOperation) {
    switch operation {
    case .reloadConfig:
      isReloadingConfig = true
    case .restartLuaRuntime:
      isRestartingLuaRuntime = true
    }
  }

  /// Marks one lifecycle operation as finished.
  private mutating func markFinished(_ operation: RuntimeLifecycleOperation) {
    switch operation {
    case .reloadConfig:
      isReloadingConfig = false
    case .restartLuaRuntime:
      isRestartingLuaRuntime = false
    }
  }

  /// Clears queued and in-flight lifecycle work.
  private mutating func resetWork() {
    isReloadingConfig = false
    isRestartingLuaRuntime = false
    queuedConfigReload = false
    queuedLuaRuntimeRestart = false
  }

  /// Dequeues the next pending lifecycle operation in priority order.
  private mutating func dequeueNextOperation() -> RuntimeLifecycleOperation? {
    if queuedConfigReload {
      queuedConfigReload = false
      return .reloadConfig
    }

    if queuedLuaRuntimeRestart {
      queuedLuaRuntimeRestart = false
      return .restartLuaRuntime
    }

    return nil
  }
}
