import EasyBarShared
import Foundation
import XCTest

@testable import EasyBar

final class LuaRenderCoalescingTests: XCTestCase {
  private var tempDirectoryURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()
    tempDirectoryURL = try makeTemporaryDirectory()
  }

  override func tearDownWithError() throws {
    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    try super.tearDownWithError()
  }

  func testExecCallbackFlushesIntermediateRenderBeforeFinalMutation() async throws {
    let widgetsDirectoryURL = tempDirectoryURL.appendingPathComponent("widgets", isDirectory: true)
    try FileManager.default.createDirectory(
      at: widgetsDirectoryURL,
      withIntermediateDirectories: true
    )

    try """
    easybar.add("item", "brew", {
    	position = "right",
    	icon = "idle",
    	label = "Idle",
    })

    easybar.subscribe("brew", { easybar.events.forced }, function(_)
    	easybar.set("brew", {
    		icon = "busy",
    		label = "Brew ...",
    	})

    	easybar.exec("printf '0'", function(output)
    		easybar.set("brew", {
    			icon = "done",
    			label = "Brew " .. output,
    		})
    	end)
    end)
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("brew.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(
      label: "lua.render-coalescing.test",
      minimumLevel: .error
    )
    let runtimeController = LuaProcessController(logger: logger)

    guard let runtimePath = runtimeController.resolvedRuntimePath() else {
      XCTFail("Missing bundled runtime.lua")
      return
    }

    let process = Process()
    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let recorder = RuntimeUpdateRecorder()

    process.executableURL = URL(fileURLWithPath: SharedPathDefaults.defaultLuaPath)
    process.arguments = [runtimePath, widgetsDirectoryURL.path, "brew.lua"]
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.environment = ProcessInfo.processInfo.environment

    let stdoutObserver = RuntimeLineObserver { line in
      guard let data = line.data(using: .utf8) else { return }

      do {
        let update = try JSONDecoder().decode(WidgetTreeUpdate.self, from: data)
        Task {
          await recorder.append(update)
        }
      } catch {
        XCTFail("Failed decoding runtime update: \(line)")
      }
    }
    stdoutObserver.attach(to: stdoutPipe.fileHandleForReading)

    let stderrObserver = RuntimeLineObserver { _ in }
    stderrObserver.attach(to: stderrPipe.fileHandleForReading)

    try process.run()
    defer {
      stdoutObserver.invalidate()
      stderrObserver.invalidate()

      try? stdinPipe.fileHandleForWriting.close()

      if process.isRunning {
        process.terminate()
        process.waitUntilExit()
      }
    }

    let initialUpdate = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.icon == "idle" }
    )
    XCTAssertEqual(rootNode(in: initialUpdate)?.text, "Idle")

    try stdinPipe.fileHandleForWriting.write(
      contentsOf: Data("{\"name\":\"forced\"}\n".utf8)
    )

    let busyUpdate = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.icon == "busy" }
    )
    XCTAssertEqual(rootNode(in: busyUpdate)?.text, "Brew ...")

    let doneUpdate = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.icon == "done" }
    )
    XCTAssertEqual(rootNode(in: doneUpdate)?.text, "Brew 0")
  }

  func testExecAsyncRequestsPollingAndDeliversCompletionLater() async throws {
    let widgetsDirectoryURL = tempDirectoryURL.appendingPathComponent("widgets", isDirectory: true)
    try FileManager.default.createDirectory(
      at: widgetsDirectoryURL,
      withIntermediateDirectories: true
    )

    try """
    easybar.add("item", "brew", {
    	position = "right",
    	icon = "idle",
    	label = "Idle",
    })

    easybar.subscribe("brew", { easybar.events.forced }, function(_)
    	easybar.set("brew", {
    		icon = "busy",
    		label = "Brew ...",
    	})

    	easybar.exec_async("printf '0'", function(output, code)
    		easybar.set("brew", {
    			icon = "done",
    			label = "Brew " .. output .. " (" .. tostring(code) .. ")",
    		})
    	end)
    end)
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("brew.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(
      label: "lua.exec-async.test",
      minimumLevel: .error
    )
    let runtimeController = LuaProcessController(logger: logger)

    guard let runtimePath = runtimeController.resolvedRuntimePath() else {
      XCTFail("Missing bundled runtime.lua")
      return
    }

    let process = Process()
    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    let recorder = RuntimeUpdateRecorder()

    process.executableURL = URL(fileURLWithPath: SharedPathDefaults.defaultLuaPath)
    process.arguments = [runtimePath, widgetsDirectoryURL.path, "brew.lua"]
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.environment = ProcessInfo.processInfo.environment

    let stdoutObserver = RuntimeLineObserver { line in
      guard let data = line.data(using: .utf8) else { return }

      do {
        let update = try JSONDecoder().decode(WidgetTreeUpdate.self, from: data)
        Task {
          await recorder.append(update)
        }
      } catch {
        XCTFail("Failed decoding runtime update: \(line)")
      }
    }
    stdoutObserver.attach(to: stdoutPipe.fileHandleForReading)

    let stderrObserver = RuntimeLineObserver { _ in }
    stderrObserver.attach(to: stderrPipe.fileHandleForReading)

    try process.run()
    defer {
      stdoutObserver.invalidate()
      stderrObserver.invalidate()

      try? stdinPipe.fileHandleForWriting.close()

      if process.isRunning {
        process.terminate()
        process.waitUntilExit()
      }
    }

    try stdinPipe.fileHandleForWriting.write(
      contentsOf: Data("{\"name\":\"forced\"}\n".utf8)
    )

    let busyUpdate = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.icon == "busy" }
    )
    XCTAssertEqual(rootNode(in: busyUpdate)?.text, "Brew ...")

    try await Task.sleep(nanoseconds: 50_000_000)

    try stdinPipe.fileHandleForWriting.write(
      contentsOf: Data("{\"name\":\"interval_tick\"}\n".utf8)
    )

    let doneUpdate = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.icon == "done" }
    )
    XCTAssertEqual(rootNode(in: doneUpdate)?.text, "Brew 0 (0)")
  }
}

extension LuaRenderCoalescingTests {
  fileprivate actor RuntimeUpdateRecorder {
    private var updates: [WidgetTreeUpdate] = []

    func append(_ update: WidgetTreeUpdate) {
      updates.append(update)
    }

    func takeFirst(
      matching predicate: @escaping (WidgetTreeUpdate) -> Bool
    ) -> WidgetTreeUpdate? {
      guard let index = updates.firstIndex(where: predicate) else {
        return nil
      }

      let update = updates[index]
      updates.remove(at: index)
      return update
    }
  }

  fileprivate final class RuntimeLineObserver {
    private let handleLine: @Sendable (String) -> Void
    private var buffer = Data()

    init(handleLine: @escaping @Sendable (String) -> Void) {
      self.handleLine = handleLine
    }

    func attach(to handle: FileHandle) {
      handle.readabilityHandler = { [weak self] readableHandle in
        guard let self else { return }

        let data = readableHandle.availableData

        if data.isEmpty {
          self.emitBufferedLineIfNeeded()
          readableHandle.readabilityHandler = nil
          return
        }

        self.buffer.append(data)

        while let newlineIndex = self.buffer.firstIndex(of: 0x0A) {
          let lineData = self.buffer.prefix(upTo: newlineIndex)
          self.buffer.removeSubrange(...newlineIndex)

          guard
            let line = String(data: lineData, encoding: .utf8)?
              .trimmingCharacters(in: .whitespacesAndNewlines),
            !line.isEmpty
          else {
            continue
          }

          self.handleLine(line)
        }
      }
    }

    func invalidate() {
      buffer.removeAll()
    }

    private func emitBufferedLineIfNeeded() {
      guard
        let line = String(data: buffer, encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines),
        !line.isEmpty
      else {
        buffer.removeAll()
        return
      }

      buffer.removeAll()
      handleLine(line)
    }
  }

  fileprivate func nextTreeUpdate(
    from recorder: RuntimeUpdateRecorder,
    matching predicate: @escaping (WidgetTreeUpdate) -> Bool,
    timeoutNanoseconds: UInt64 = 2_000_000_000
  ) async throws -> WidgetTreeUpdate {
    return try await nextUpdate(
      from: recorder,
      matching: predicate,
      timeoutNanoseconds: timeoutNanoseconds
    )
  }

  fileprivate func nextUpdate(
    from recorder: RuntimeUpdateRecorder,
    matching predicate: @escaping (WidgetTreeUpdate) -> Bool,
    timeoutNanoseconds: UInt64 = 2_000_000_000
  ) async throws -> WidgetTreeUpdate {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while DispatchTime.now().uptimeNanoseconds < deadline {
      if let update = await recorder.takeFirst(matching: predicate) {
        return update
      }

      try await Task.sleep(nanoseconds: 10_000_000)
    }

    throw NSError(
      domain: "LuaRenderCoalescingTests",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey: "Timed out waiting for matching widget tree update"
      ]
    )
  }

  fileprivate func rootNode(in update: WidgetTreeUpdate) -> WidgetNodeState? {
    guard let payload = update.treePayload else {
      return nil
    }

    return payload.nodes.first(where: { $0.id == payload.root })
  }

  fileprivate func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "easybar-lua-render-coalescing-tests-\(UUID().uuidString)",
        isDirectory: true
      )

    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    return directoryURL
  }
}
