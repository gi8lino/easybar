import Foundation
import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

@MainActor
final class AeroSpaceServiceRecoveryTests: XCTestCase {
  private final class ScriptedRunner: AeroSpaceCommandRunning, @unchecked Sendable {
    private struct State {
      var versionFailuresRemaining = 0
      var snapshotFailuresEnabled = false
      var workspaceName = "1"
      var snapshotDelayNanoseconds: UInt64 = 0
      var versionCallCount = 0
      var workspaceCallCount = 0
      var activeCalls = 0
      var maximumActiveCalls = 0
      var cancellationCount = 0
    }

    private let state = LockedState(State())

    func run(arguments: [String]) async -> String? {
      state.withLock { state in
        state.activeCalls += 1
        state.maximumActiveCalls = max(state.maximumActiveCalls, state.activeCalls)
      }
      defer {
        state.withLock { state in state.activeCalls -= 1 }
      }

      if arguments == ["--version"] {
        let shouldFail = state.withLock { state -> Bool in
          state.versionCallCount += 1
          guard state.versionFailuresRemaining > 0 else { return false }
          state.versionFailuresRemaining -= 1
          return true
        }
        if shouldFail { return nil }
        return Self.supportedVersionOutput
      }

      let delay = state.withLock(\.snapshotDelayNanoseconds)
      if delay > 0 {
        do {
          try await Task.sleep(nanoseconds: delay)
        } catch {
          state.withLock { $0.cancellationCount += 1 }
          return nil
        }
      }
      guard !Task.isCancelled else {
        state.withLock { $0.cancellationCount += 1 }
        return nil
      }

      let snapshotState = state.withLock { state in
        (
          shouldFail: state.snapshotFailuresEnabled,
          workspaceName: state.workspaceName
        )
      }
      if snapshotState.shouldFail { return nil }

      switch arguments.first {
      case "list-workspaces":
        state.withLock { $0.workspaceCallCount += 1 }
        return
          """
          [
            {"workspace":"\(snapshotState.workspaceName)","workspace-is-focused":true,"workspace-is-visible":true}
          ]
          """
      case "list-windows":
        if arguments.contains("--focused") {
          return "[]"
        }
        return "[]"
      default:
        return nil
      }
    }

    func failNextVersionChecks(_ count: Int) {
      state.withLock { $0.versionFailuresRemaining = count }
    }

    func setSnapshotFailuresEnabled(_ enabled: Bool) {
      state.withLock { $0.snapshotFailuresEnabled = enabled }
    }

    func setWorkspaceName(_ name: String) {
      state.withLock { $0.workspaceName = name }
    }

    func setSnapshotDelayNanoseconds(_ value: UInt64) {
      state.withLock { $0.snapshotDelayNanoseconds = value }
    }

    var versionCallCount: Int { state.withLock(\.versionCallCount) }
    var workspaceCallCount: Int { state.withLock(\.workspaceCallCount) }
    var maximumActiveCalls: Int { state.withLock(\.maximumActiveCalls) }
    var cancellationCount: Int { state.withLock(\.cancellationCount) }

    private static let supportedVersionOutput =
      """
      aerospace CLI client version: 0.21.1-Beta
      AeroSpace.app server version: 0.21.1-Beta
      """
  }

  private final class RecordingSubscriptionController: AeroSpaceSubscriptionControlling,
    @unchecked Sendable
  {
    private struct State {
      var starts = 0
      var stops = 0
    }

    private let state = LockedState(State())

    func start() { state.withLock { $0.starts += 1 } }
    func stop() { state.withLock { $0.stops += 1 } }

    var startCount: Int { state.withLock(\.starts) }
  }

  private final class RecordingRetryScheduler: AeroSpaceReconnectScheduling,
    @unchecked Sendable
  {
    private struct State {
      var actions: [@Sendable () -> Void] = []
      var resetCount = 0
    }

    private let state = LockedState(State())

    func schedule(_ action: @escaping @Sendable () -> Void) {
      state.withLock { state in
        guard state.actions.isEmpty else { return }
        state.actions.append(action)
      }
    }

    func cancel() {
      state.withLock { state in
        state.actions.removeAll()
        state.resetCount += 1
      }
    }

    func resetDelay() {
      state.withLock { $0.resetCount += 1 }
    }

    var scheduledCount: Int { state.withLock { $0.actions.count } }

    @discardableResult
    func runNext() -> Bool {
      let action = state.withLock { state -> (@Sendable () -> Void)? in
        guard !state.actions.isEmpty else { return nil }
        return state.actions.removeFirst()
      }
      guard let action else { return false }
      action()
      return true
    }
  }

  func testRetainsLastKnownGoodSnapshotAfterCommandFailure() async {
    let runner = ScriptedRunner()
    let retry = RecordingRetryScheduler()
    let service = makeService(runner: runner, retry: retry)

    service.start()
    service.registerConsumer("test") {}
    defer { service.stop() }

    let becameCurrent = await waitUntil { service.snapshotStatus == .current }
    XCTAssertTrue(becameCurrent)
    XCTAssertEqual(service.spaces.map(\.name), ["1"])

    runner.setSnapshotFailuresEnabled(true)
    service.refresh()

    let becameStale = await waitUntil {
      if case .stale = service.snapshotStatus { return true }
      return false
    }
    XCTAssertTrue(becameStale)
    XCTAssertEqual(service.spaces.map(\.name), ["1"])
    XCTAssertEqual(retry.scheduledCount, 1)
  }

  func testRetriesTransientVersionFailureWithoutRestartingService() async {
    let runner = ScriptedRunner()
    runner.failNextVersionChecks(1)
    let retry = RecordingRetryScheduler()
    let subscription = RecordingSubscriptionController()
    let service = makeService(
      runner: runner,
      retry: retry,
      subscription: subscription
    )

    service.start()
    service.registerConsumer("test") {}
    defer { service.stop() }

    let retryScheduled = await waitUntil { retry.scheduledCount == 1 }
    XCTAssertTrue(retryScheduled)
    XCTAssertEqual(runner.versionCallCount, 1)
    XCTAssertEqual(subscription.startCount, 1)

    XCTAssertTrue(retry.runNext())
    let recovered = await waitUntil { service.snapshotStatus == .current }
    XCTAssertTrue(recovered)
    XCTAssertEqual(runner.versionCallCount, 2)
    XCTAssertEqual(service.spaces.map(\.name), ["1"])
  }

  func testBurstRefreshesCancelSupersededSnapshotCommands() async {
    let runner = ScriptedRunner()
    runner.setSnapshotDelayNanoseconds(150_000_000)
    let service = makeService(runner: runner, retry: RecordingRetryScheduler())

    service.start()
    service.registerConsumer("test") {}
    defer { service.stop() }

    let versionChecked = await waitUntil { runner.versionCallCount == 1 }
    XCTAssertTrue(versionChecked)

    for index in 2...6 {
      runner.setWorkspaceName(String(index))
      service.refresh()
      try? await Task.sleep(nanoseconds: 10_000_000)
    }

    let latestPublished = await waitUntil(timeout: 2) {
      service.snapshotStatus == .current
    }
    XCTAssertTrue(latestPublished)
    XCTAssertEqual(service.spaces.map(\.name), ["6"])
    XCTAssertGreaterThan(runner.cancellationCount, 0)
    XCTAssertLessThanOrEqual(runner.maximumActiveCalls, 2)
    XCTAssertEqual(runner.versionCallCount, 1)
  }

  private func makeService(
    runner: ScriptedRunner,
    retry: RecordingRetryScheduler,
    subscription: RecordingSubscriptionController = RecordingSubscriptionController()
  ) -> AeroSpaceService {
    let logger = ProcessLogger(
      label: "easybar.aerospace.service.tests",
      minimumLevel: .error,
      outputStream: nil,
      errorStream: nil
    )
    let eventHub = EventHub(logger: logger, enqueueLuaEvent: { _ in })
    return AeroSpaceService(
      logger: logger,
      eventHub: eventHub,
      commandRunner: runner,
      subscriptionController: subscription,
      refreshRetryScheduler: retry
    )
  }

  private func waitUntil(
    timeout: TimeInterval = 1,
    condition: @escaping @MainActor () -> Bool
  ) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return true }
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    return condition()
  }
}
