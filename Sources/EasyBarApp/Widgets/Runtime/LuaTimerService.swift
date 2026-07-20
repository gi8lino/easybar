import EasyBarShared
import Foundation

/// Owns host-side one-shot timers requested by the Lua runtime.
actor LuaTimerService {
  private struct ActiveTimer {
    let runtimeSessionID: UInt64
    let task: Task<Void, Never>
  }

  private struct LuaTimerResponse: Encodable {
    let protocolVersion = easyBarLuaRuntimeProtocolVersion
    let type = "timer_fired"
    let token: String

    enum CodingKeys: String, CodingKey {
      case protocolVersion = "protocol_version"
      case type
      case token
    }
  }

  private let logger: ProcessLogger
  private let luaRuntime: LuaRuntime
  private let encoder = JSONEncoder()
  private var activeTimers: [String: ActiveTimer] = [:]
  private var activeRuntimeSessionID: UInt64?

  init(logger: ProcessLogger, luaRuntime: LuaRuntime) {
    self.logger = logger
    self.luaRuntime = luaRuntime
  }

  /// Cancels and forgets every timer owned by the current Lua runtime session.
  func reset() {
    let tasks = activeTimers.values.map(\.task)
    activeTimers.removeAll()
    activeRuntimeSessionID = nil
    for task in tasks {
      task.cancel()
    }
  }

  /// Schedules one non-blocking one-shot timer for the active runtime session.
  func schedule(
    token: String,
    delaySeconds: TimeInterval,
    runtimeSessionID: UInt64,
    isRuntimeSessionActive: @escaping @Sendable (UInt64) async -> Bool
  ) {
    if activeRuntimeSessionID != runtimeSessionID {
      reset()
      activeRuntimeSessionID = runtimeSessionID
    }

    activeTimers[token]?.task.cancel()
    let nanoseconds = clampedSleepNanoseconds(from: delaySeconds)
    let task = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: nanoseconds)
      } catch {
        return
      }
      await self?.fire(
        token: token,
        runtimeSessionID: runtimeSessionID,
        isRuntimeSessionActive: isRuntimeSessionActive
      )
    }
    activeTimers[token] = ActiveTimer(runtimeSessionID: runtimeSessionID, task: task)

    logger.debug(
      "lua timer scheduled",
      .field("token", token),
      .field("delay_seconds", delaySeconds)
    )
  }

  /// Cancels one pending timer owned by the active runtime session.
  func cancel(token: String, runtimeSessionID: UInt64) {
    guard activeRuntimeSessionID == runtimeSessionID,
      let timer = activeTimers.removeValue(forKey: token),
      timer.runtimeSessionID == runtimeSessionID
    else {
      return
    }
    timer.task.cancel()
    logger.debug("lua timer cancelled", .field("token", token))
  }

  private func fire(
    token: String,
    runtimeSessionID: UInt64,
    isRuntimeSessionActive: @escaping @Sendable (UInt64) async -> Bool
  ) async {
    guard activeRuntimeSessionID == runtimeSessionID,
      let timer = activeTimers.removeValue(forKey: token),
      timer.runtimeSessionID == runtimeSessionID,
      await isRuntimeSessionActive(runtimeSessionID)
    else {
      return
    }

    let response = LuaTimerResponse(token: token)
    guard
      let data = try? encoder.encode(response),
      let encoded = String(data: data, encoding: .utf8)
    else {
      logger.error("failed to encode lua timer response", .field("token", token))
      return
    }

    await luaRuntime.send(encoded)
  }
}
