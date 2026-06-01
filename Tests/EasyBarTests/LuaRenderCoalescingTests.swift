import Darwin
import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class LuaRenderCoalescingTests: XCTestCase {
  private let decoder = JSONDecoder()

  private var originalConfigSnapshot: ConfigSnapshot!
  private var tempDirectoryURL: URL!
  private var configFileURL: URL!
  private var lockDirectoryURL: URL!
  private var loggingDirectoryURL: URL!
  private var runtimeDirectoryURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()

    originalConfigSnapshot = Config.shared.snapshot()
    Config.shared.resetToDefaults()

    tempDirectoryURL = try makeTemporaryDirectory()
    configFileURL = tempDirectoryURL.appendingPathComponent("config.toml")
    lockDirectoryURL = tempDirectoryURL.appendingPathComponent("locks", isDirectory: true)
    loggingDirectoryURL = tempDirectoryURL.appendingPathComponent("logs", isDirectory: true)
    runtimeDirectoryURL = tempDirectoryURL.appendingPathComponent("runtime", isDirectory: true)
  }

  override func tearDownWithError() throws {
    Config.shared.apply(originalConfigSnapshot)

    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    try super.tearDownWithError()
  }

  func testExecCallbackFlushesIntermediateRenderBeforeFinalMutation() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

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
    let hostBridge = RuntimeHostBridge(
      recorder: recorder,
      decoder: decoder,
      stdinHandle: stdinPipe.fileHandleForWriting,
      asyncResponseDelayNanoseconds: 0
    )

    process.executableURL = URL(fileURLWithPath: SharedPathDefaults.defaultLuaPath)
    process.arguments = [runtimePath, widgetsDirectoryURL.path, "brew.lua"]
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.environment = try luaRuntimeEnvironment(for: widgetsDirectoryURL)

    let stdoutObserver = RuntimeLineObserver { line in
      do {
        try await hostBridge.handleRuntimeLine(line)
      } catch {
        XCTFail("Failed handling runtime update: \(line) error=\(error)")
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

      terminate(process)
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

  func testExecAsyncDeliversCompletionLaterWithoutPollingTick() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

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
    let hostBridge = RuntimeHostBridge(
      recorder: recorder,
      decoder: decoder,
      stdinHandle: stdinPipe.fileHandleForWriting,
      asyncResponseDelayNanoseconds: 50_000_000
    )

    process.executableURL = URL(fileURLWithPath: SharedPathDefaults.defaultLuaPath)
    process.arguments = [runtimePath, widgetsDirectoryURL.path, "brew.lua"]
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.environment = try luaRuntimeEnvironment(for: widgetsDirectoryURL)

    let stdoutObserver = RuntimeLineObserver { line in
      do {
        try await hostBridge.handleRuntimeLine(line)
      } catch {
        XCTFail("Failed handling runtime update: \(line) error=\(error)")
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

      terminate(process)
    }

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
    XCTAssertEqual(rootNode(in: doneUpdate)?.text, "Brew 0 (0)")
  }

  func testStaleCommandResponseFromPreviousRuntimeDoesNotSatisfyNewSyncCommand() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

    let logger = ProcessLogger(
      label: "lua.stale-command-response.test",
      minimumLevel: .error
    )
    let runtimeController = LuaProcessController(logger: logger)

    guard let runtimePath = runtimeController.resolvedRuntimePath() else {
      XCTFail("Missing bundled runtime.lua")
      return
    }

    try """
    easybar.add("item", "brew", {
    	position = "right",
    	icon = "idle",
    	label = "Idle",
    })

    easybar.subscribe("brew", { easybar.events.forced }, function(_)
    	easybar.exec_async("printf 'old'", function(output)
    		easybar.set("brew", {
    			label = output,
    		})
    	end)
    end)
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("old.lua"),
      atomically: true,
      encoding: .utf8
    )

    let oldRecorder = RuntimeUpdateRecorder()
    let oldRuntime = try RuntimeProcess(
      runtimePath: runtimePath,
      widgetsDirectoryURL: widgetsDirectoryURL,
      widgetFile: "old.lua",
      recorder: oldRecorder,
      decoder: decoder,
      environment: try luaRuntimeEnvironment(for: widgetsDirectoryURL),
      autoRespondToCommands: false
    )
    defer { oldRuntime.stop() }

    try oldRuntime.sendHostEvent("{\"name\":\"forced\"}\n")

    let oldRequest = try await nextCommandRequest(
      from: oldRecorder,
      matching: { !$0.isSynchronous && $0.command == "printf 'old'" }
    )

    oldRuntime.stop()

    try """
    easybar.add("item", "brew", {
    	position = "right",
    	icon = "idle",
    	label = "Idle",
    })

    easybar.subscribe("brew", { easybar.events.forced }, function(_)
    	easybar.exec("printf 'fresh'", function(output)
    		easybar.set("brew", {
    			icon = "done",
    			label = output,
    		})
    	end)
    end)
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("new.lua"),
      atomically: true,
      encoding: .utf8
    )

    let newRecorder = RuntimeUpdateRecorder()
    let newRuntime = try RuntimeProcess(
      runtimePath: runtimePath,
      widgetsDirectoryURL: widgetsDirectoryURL,
      widgetFile: "new.lua",
      recorder: newRecorder,
      decoder: decoder,
      environment: try luaRuntimeEnvironment(for: widgetsDirectoryURL),
      autoRespondToCommands: false
    )
    defer { newRuntime.stop() }

    try newRuntime.sendHostEvent("{\"name\":\"forced\"}\n")

    let newRequest = try await nextCommandRequest(
      from: newRecorder,
      matching: { $0.isSynchronous && $0.command == "printf 'fresh'" }
    )

    try newRuntime.sendCommandResponse(
      token: oldRequest.token,
      output: "stale",
      status: 0
    )
    try newRuntime.sendCommandResponse(
      token: newRequest.token,
      output: "fresh",
      status: 0
    )

    let doneUpdate = try await nextTreeUpdate(
      from: newRecorder,
      matching: { [self] in rootNode(in: $0)?.icon == "done" }
    )
    XCTAssertEqual(rootNode(in: doneUpdate)?.text, "fresh")
  }

  func testRemovingRootEmitsExplicitClearRootUpdate() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

    try """
    local brew = easybar.add("item", "brew", {
    	position = "right",
    	icon = "idle",
    	label = "Idle",
    })

    brew:subscribe(easybar.events.forced, function()
    	brew:remove()
    end)
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("brew.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(
      label: "lua.clear-root.test",
      minimumLevel: .error
    )
    let runtimeController = LuaProcessController(logger: logger)

    guard let runtimePath = runtimeController.resolvedRuntimePath() else {
      XCTFail("Missing bundled runtime.lua")
      return
    }

    let recorder = RuntimeUpdateRecorder()
    let runtime = try RuntimeProcess(
      runtimePath: runtimePath,
      widgetsDirectoryURL: widgetsDirectoryURL,
      widgetFile: "brew.lua",
      recorder: recorder,
      decoder: decoder,
      environment: try luaRuntimeEnvironment(for: widgetsDirectoryURL),
      autoRespondToCommands: true
    )
    defer {
      runtime.stop()
    }

    let initialUpdate = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.id == "brew" }
    )
    XCTAssertEqual(rootNode(in: initialUpdate)?.text, "Idle")

    try runtime.sendHostEvent("{\"name\":\"forced\"}\n")

    let clearUpdate = try await nextUpdate(
      from: recorder,
      matching: { update in
        update.isClearRoot && update.clearRootID == "brew"
      }
    )
    XCTAssertEqual(clearUpdate.clearRootID, "brew")
  }

  func testUnsetClearsNestedProperties() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

    try """
    local brew = easybar.add("item", "brew", {
    	position = "right",
    	label = {
    		string = "Idle",
    		color = "#ff0000",
    	},
    })

    brew:subscribe(easybar.events.forced, function()
    	brew:unset("label.color")
    end)
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("brew.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(
      label: "lua.unset.test",
      minimumLevel: .error
    )
    let runtimeController = LuaProcessController(logger: logger)

    guard let runtimePath = runtimeController.resolvedRuntimePath() else {
      XCTFail("Missing bundled runtime.lua")
      return
    }

    let recorder = RuntimeUpdateRecorder()
    let runtime = try RuntimeProcess(
      runtimePath: runtimePath,
      widgetsDirectoryURL: widgetsDirectoryURL,
      widgetFile: "brew.lua",
      recorder: recorder,
      decoder: decoder,
      environment: try luaRuntimeEnvironment(for: widgetsDirectoryURL),
      autoRespondToCommands: true
    )
    defer {
      runtime.stop()
    }

    let initialUpdate = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.id == "brew" }
    )
    XCTAssertEqual(rootNode(in: initialUpdate)?.labelColor, "#ff0000")

    try runtime.sendHostEvent("{\"name\":\"forced\"}\n")

    let updated = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in
        let root = rootNode(in: $0)
        return root?.id == "brew" && root?.labelColor == nil
      }
    )

    XCTAssertNil(rootNode(in: updated)?.labelColor)
  }

  func testInvalidBooleanValueFallsBackOutsideStrictMode() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

    try """
    easybar.add("item", "brew", {
    	position = "right",
    	drawing = "maybe",
    	label = "Idle",
    })
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("brew.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(
      label: "lua.invalid-bool-fallback.test",
      minimumLevel: .error
    )
    let runtimeController = LuaProcessController(logger: logger)

    guard let runtimePath = runtimeController.resolvedRuntimePath() else {
      XCTFail("Missing bundled runtime.lua")
      return
    }

    let recorder = RuntimeUpdateRecorder()
    let runtime = try RuntimeProcess(
      runtimePath: runtimePath,
      widgetsDirectoryURL: widgetsDirectoryURL,
      widgetFile: "brew.lua",
      recorder: recorder,
      decoder: decoder,
      environment: try luaRuntimeEnvironment(for: widgetsDirectoryURL),
      autoRespondToCommands: true,
      environmentOverrides: ["EASYBAR_STRICT_PUBLIC_API": "0"]
    )
    defer {
      runtime.stop()
    }

    let update = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.id == "brew" }
    )

    XCTAssertTrue(rootNode(in: update)?.visible ?? false)
  }

  func testInvalidBooleanValueFailsInStrictMode() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

    try """
    easybar.add("item", "brew", {
    	position = "right",
    	drawing = "maybe",
    	label = "Idle",
    })
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("brew.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(
      label: "lua.invalid-bool-strict.test",
      minimumLevel: .error
    )
    let runtimeController = LuaProcessController(logger: logger)

    guard let runtimePath = runtimeController.resolvedRuntimePath() else {
      XCTFail("Missing bundled runtime.lua")
      return
    }

    let recorder = RuntimeUpdateRecorder()
    let runtime = try RuntimeProcess(
      runtimePath: runtimePath,
      widgetsDirectoryURL: widgetsDirectoryURL,
      widgetFile: "brew.lua",
      recorder: recorder,
      decoder: decoder,
      environment: try luaRuntimeEnvironment(for: widgetsDirectoryURL),
      autoRespondToCommands: true,
      environmentOverrides: ["EASYBAR_STRICT_PUBLIC_API": "1"]
    )
    defer {
      runtime.stop()
    }

    try await expectNoUpdate(
      from: recorder,
      matching: { update in
        update.isTree
      }
    )
  }

  func testPublicWidgetApiExposesJsonHelper() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

    try """
    local payload = easybar.json.decode('{"name":"brew","count":2}')

    easybar.add("item", "brew", {
    	position = "right",
    	icon = payload.name,
    	label = tostring(payload.count),
    })
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("brew.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(
      label: "lua.public-json.test",
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
    let hostBridge = RuntimeHostBridge(
      recorder: recorder,
      decoder: decoder,
      stdinHandle: stdinPipe.fileHandleForWriting,
      asyncResponseDelayNanoseconds: 0
    )

    process.executableURL = URL(fileURLWithPath: SharedPathDefaults.defaultLuaPath)
    process.arguments = [runtimePath, widgetsDirectoryURL.path, "brew.lua"]
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.environment = try luaRuntimeEnvironment(for: widgetsDirectoryURL)

    let stdoutObserver = RuntimeLineObserver { line in
      do {
        try await hostBridge.handleRuntimeLine(line)
      } catch {
        XCTFail("Failed handling runtime update: \(line) error=\(error)")
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

      terminate(process)
    }

    let initialUpdate = try await nextTreeUpdate(
      from: recorder,
      matching: { [self] in rootNode(in: $0)?.icon == "brew" }
    )
    XCTAssertEqual(rootNode(in: initialUpdate)?.text, "2")
  }

  func testIntervalSubscriptionChangesAreReemittedAfterWidgetMutation() async throws {
    let widgetsDirectoryURL = try makeWidgetsDirectory()

    try """
    local brew

    brew = easybar.add("item", "brew", {
    	position = "right",
    	interval = 60,
    	label = "60",
    	on_interval = function()
    		brew:set({
    			label = "tick",
    		})
    	end,
    })

    brew:subscribe(easybar.events.forced, function()
    	brew:set({
    		interval = 5,
    		label = "5",
    		on_interval = function()
    			brew:set({
    				label = "tick-fast",
    			})
    		end,
    	})
    end)
    """.write(
      to: widgetsDirectoryURL.appendingPathComponent("brew.lua"),
      atomically: true,
      encoding: .utf8
    )

    let logger = ProcessLogger(
      label: "lua.interval-resubscribe.test",
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
    let hostBridge = RuntimeHostBridge(
      recorder: recorder,
      decoder: decoder,
      stdinHandle: stdinPipe.fileHandleForWriting,
      asyncResponseDelayNanoseconds: 0
    )

    process.executableURL = URL(fileURLWithPath: SharedPathDefaults.defaultLuaPath)
    process.arguments = [runtimePath, widgetsDirectoryURL.path, "brew.lua"]
    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    process.environment = try luaRuntimeEnvironment(for: widgetsDirectoryURL)

    let stdoutObserver = RuntimeLineObserver { line in
      do {
        try await hostBridge.handleRuntimeLine(line)
      } catch {
        XCTFail("Failed handling runtime update: \(line) error=\(error)")
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

      terminate(process)
    }

    let initialSubscriptions = try await nextUpdate(
      from: recorder,
      matching: { update in
        update.isSubscriptions && Set(update.subscribedEvents) == ["forced", "interval_tick:brew:60"]
      }
    )
    XCTAssertEqual(Set(initialSubscriptions.subscribedEvents), ["forced", "interval_tick:brew:60"])

    try stdinPipe.fileHandleForWriting.write(
      contentsOf: Data("{\"name\":\"forced\"}\n".utf8)
    )

    let updatedSubscriptions = try await nextUpdate(
      from: recorder,
      matching: { update in
        update.isSubscriptions && Set(update.subscribedEvents) == ["forced", "interval_tick:brew:5"]
      }
    )
    XCTAssertEqual(Set(updatedSubscriptions.subscribedEvents), ["forced", "interval_tick:brew:5"])
  }
}

extension LuaRenderCoalescingTests {
  fileprivate struct RuntimeCommandRequest: Equatable {
    let token: String
    let command: String
    let isSynchronous: Bool
  }

  fileprivate actor RuntimeHostBridge {
    private let recorder: RuntimeUpdateRecorder
    private let decoder: JSONDecoder
    private let stdinHandle: FileHandle
    private let asyncResponseDelayNanoseconds: UInt64
    private let autoRespondToCommands: Bool

    init(
      recorder: RuntimeUpdateRecorder,
      decoder: JSONDecoder,
      stdinHandle: FileHandle,
      asyncResponseDelayNanoseconds: UInt64,
      autoRespondToCommands: Bool = true
    ) {
      self.recorder = recorder
      self.decoder = decoder
      self.stdinHandle = stdinHandle
      self.asyncResponseDelayNanoseconds = asyncResponseDelayNanoseconds
      self.autoRespondToCommands = autoRespondToCommands
    }

    func handleRuntimeLine(_ line: String) async throws {
      let update = try decoder.decode(WidgetTreeUpdate.self, from: Data(line.utf8))
      await recorder.record(summary: describe(update))

      if let request = update.commandRequestPayload {
        await recorder.append(
          RuntimeCommandRequest(
            token: request.token,
            command: request.command,
            isSynchronous: request.isSynchronous
          )
        )

        guard autoRespondToCommands else { return }

        if !request.isSynchronous && asyncResponseDelayNanoseconds > 0 {
          try await Task.sleep(nanoseconds: asyncResponseDelayNanoseconds)
        }

        try sendCommandResponse(token: request.token, output: "0", status: 0)
        return
      }

      await recorder.append(update)
    }

    private func describe(_ update: WidgetTreeUpdate) -> String {
      switch update.type {
      case .subscriptions:
        return "subscriptions:\(update.subscribedEvents.joined(separator: ","))"
      case .ready:
        return "ready"
      case .clearRoot:
        return "clear_root:\(update.clearRootID ?? "unknown")"
      case .commandRequest:
        if let request = update.commandRequestPayload {
          return "command_request:\(request.command):sync=\(request.isSynchronous)"
        }
        return "command_request"
      case .tree:
        if let payload = update.treePayload,
          let root = payload.nodes.first(where: { $0.id == payload.root })
        {
          return "tree:\(payload.root):icon=\(root.icon):text=\(root.text)"
        }
        return "tree"
      }
    }

    private func sendCommandResponse(token: String, output: String, status: Int) throws {
      let payload = """
        {"protocol_version":1,"type":"command_response","token":"\(token)","output":"\(output)","status":\(status)}
        \n
        """
      try stdinHandle.write(contentsOf: Data(payload.utf8))
    }
  }

  fileprivate actor RuntimeUpdateRecorder {
    private var updates: [WidgetTreeUpdate] = []
    private var commandRequests: [RuntimeCommandRequest] = []
    private var summaries: [String] = []

    func append(_ update: WidgetTreeUpdate) {
      updates.append(update)
    }

    func append(_ request: RuntimeCommandRequest) {
      commandRequests.append(request)
    }

    func record(summary: String) {
      summaries.append(summary)
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

    func debugSummaries() -> [String] {
      summaries
    }

    func takeFirstCommandRequest(
      matching predicate: @escaping (RuntimeCommandRequest) -> Bool
    ) -> RuntimeCommandRequest? {
      guard let index = commandRequests.firstIndex(where: predicate) else {
        return nil
      }

      let request = commandRequests[index]
      commandRequests.remove(at: index)
      return request
    }
  }

  fileprivate final class RuntimeProcess {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let stdoutObserver: RuntimeLineObserver
    private let stderrObserver: RuntimeLineObserver

    init(
      runtimePath: String,
      widgetsDirectoryURL: URL,
      widgetFile: String,
      recorder: RuntimeUpdateRecorder,
      decoder: JSONDecoder,
      environment: [String: String],
      autoRespondToCommands: Bool,
      environmentOverrides: [String: String] = [:]
    ) throws {
      let hostBridge = RuntimeHostBridge(
        recorder: recorder,
        decoder: decoder,
        stdinHandle: stdinPipe.fileHandleForWriting,
        asyncResponseDelayNanoseconds: 0,
        autoRespondToCommands: autoRespondToCommands
      )

      process.executableURL = URL(fileURLWithPath: SharedPathDefaults.defaultLuaPath)
      process.arguments = [runtimePath, widgetsDirectoryURL.path, widgetFile]
      process.standardInput = stdinPipe
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe
      process.environment = environment.merging(environmentOverrides) {
        _, override in override
      }

      stdoutObserver = RuntimeLineObserver { line in
        do {
          try await hostBridge.handleRuntimeLine(line)
        } catch {
          XCTFail("Failed handling runtime update: \(line) error=\(error)")
        }
      }
      stdoutObserver.attach(to: stdoutPipe.fileHandleForReading)

      stderrObserver = RuntimeLineObserver { _ in }
      stderrObserver.attach(to: stderrPipe.fileHandleForReading)

      try process.run()
    }

    func sendHostEvent(_ payload: String) throws {
      try stdinPipe.fileHandleForWriting.write(contentsOf: Data(payload.utf8))
    }

    func sendCommandResponse(token: String, output: String, status: Int) throws {
      let payload = """
        {"protocol_version":1,"type":"command_response","token":"\(token)","output":"\(output)","status":\(status)}
        \n
        """
      try sendHostEvent(payload)
    }

    func stop() {
      stdoutObserver.invalidate()
      stderrObserver.invalidate()

      try? stdinPipe.fileHandleForWriting.close()

      terminate(process)
    }
  }

  fileprivate final class RuntimeLineObserver {
    private let handleLine: @Sendable (String) async -> Void
    private var buffer = Data()
    private var pendingLineTask: Task<Void, Never>?

    init(handleLine: @escaping @Sendable (String) async -> Void) {
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

          self.enqueue(line)
        }
      }
    }

    func invalidate() {
      buffer.removeAll()
      pendingLineTask?.cancel()
      pendingLineTask = nil
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
      enqueue(line)
    }

    private func enqueue(_ line: String) {
      let previousTask = pendingLineTask

      pendingLineTask = Task {
        _ = await previousTask?.result

        guard !Task.isCancelled else {
          return
        }

        await handleLine(line)
      }
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

    let summaries = await recorder.debugSummaries().joined(separator: " | ")

    throw NSError(
      domain: "LuaRenderCoalescingTests",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey:
          "Timed out waiting for matching widget tree update; seen updates: \(summaries)"
      ]
    )
  }

  fileprivate func nextCommandRequest(
    from recorder: RuntimeUpdateRecorder,
    matching predicate: @escaping (RuntimeCommandRequest) -> Bool,
    timeoutNanoseconds: UInt64 = 2_000_000_000
  ) async throws -> RuntimeCommandRequest {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while DispatchTime.now().uptimeNanoseconds < deadline {
      if let request = await recorder.takeFirstCommandRequest(matching: predicate) {
        return request
      }

      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let summaries = await recorder.debugSummaries().joined(separator: " | ")

    throw NSError(
      domain: "LuaRenderCoalescingTests",
      code: 2,
      userInfo: [
        NSLocalizedDescriptionKey:
          "Timed out waiting for matching command request; seen updates: \(summaries)"
      ]
    )
  }

  fileprivate func expectNoUpdate(
    from recorder: RuntimeUpdateRecorder,
    matching predicate: @escaping (WidgetTreeUpdate) -> Bool,
    timeoutNanoseconds: UInt64 = 300_000_000
  ) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while DispatchTime.now().uptimeNanoseconds < deadline {
      if let update = await recorder.takeFirst(matching: predicate) {
        throw NSError(
          domain: "LuaRenderCoalescingTests",
          code: 3,
          userInfo: [
            NSLocalizedDescriptionKey: "Unexpected update: \(update.type)"
          ]
        )
      }

      try await Task.sleep(nanoseconds: 10_000_000)
    }
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

  fileprivate func makeWidgetsDirectory() throws -> URL {
    let widgetsDirectoryURL = tempDirectoryURL.appendingPathComponent(
      "widgets",
      isDirectory: true
    )

    try FileManager.default.createDirectory(
      at: widgetsDirectoryURL,
      withIntermediateDirectories: true
    )

    return widgetsDirectoryURL
  }

  fileprivate func luaRuntimeEnvironment(
    for widgetsDirectoryURL: URL
  ) throws -> [String: String] {
    try writeTestConfig(widgetsDirectoryURL: widgetsDirectoryURL)

    var environment = ProcessInfo.processInfo.environment

    for key in Array(environment.keys) where key.hasPrefix("EASYBAR_") {
      environment.removeValue(forKey: key)
    }

    for key in sharedRuntimeEnvironmentKeys {
      environment.removeValue(forKey: key)
    }

    let luaSocketPath = runtimeDirectoryURL.appendingPathComponent("lua.sock").path
    let calendarSocketPath = runtimeDirectoryURL.appendingPathComponent("calendar.sock").path
    let networkSocketPath = runtimeDirectoryURL.appendingPathComponent("network.sock").path

    environment[SharedEnvironmentKeys.configPath] = configFileURL.path
    environment[SharedEnvironmentKeys.lockDirectory] = lockDirectoryURL.path
    environment[SharedEnvironmentKeys.loggingDirectory] = loggingDirectoryURL.path
    environment[SharedEnvironmentKeys.loggingLevel] = "error"
    environment[SharedEnvironmentKeys.luaSocketPath] = luaSocketPath
    environment[SharedEnvironmentKeys.calendarAgentSocketPath] = calendarSocketPath
    environment[SharedEnvironmentKeys.networkAgentSocketPath] = networkSocketPath
    environment[SharedEnvironmentKeys.networkAgentRefreshIntervalSeconds] = "60"

    environment.merge(Config.shared.luaThemeEnvironment()) {
      _, testValue in testValue
    }

    return environment
  }

  fileprivate var sharedRuntimeEnvironmentKeys: [String] {
    [
      SharedEnvironmentKeys.configPath,
      SharedEnvironmentKeys.lockDirectory,
      SharedEnvironmentKeys.loggingDirectory,
      SharedEnvironmentKeys.loggingLevel,
      SharedEnvironmentKeys.luaSocketPath,
      SharedEnvironmentKeys.calendarAgentSocketPath,
      SharedEnvironmentKeys.networkAgentSocketPath,
      SharedEnvironmentKeys.networkAgentRefreshIntervalSeconds,
    ]
  }

  fileprivate func writeTestConfig(widgetsDirectoryURL: URL) throws {
    try FileManager.default.createDirectory(
      at: widgetsDirectoryURL,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: lockDirectoryURL,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: loggingDirectoryURL,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: runtimeDirectoryURL,
      withIntermediateDirectories: true
    )

    let luaSocketPath = runtimeDirectoryURL.appendingPathComponent("lua.sock").path
    let calendarSocketPath = runtimeDirectoryURL.appendingPathComponent("calendar.sock").path
    let networkSocketPath = runtimeDirectoryURL.appendingPathComponent("network.sock").path

    try """
    [app]
    widgets_dir = "\(tomlEscaped(widgetsDirectoryURL.path))"
    lua_path = "\(tomlEscaped(SharedPathDefaults.defaultLuaPath))"
    lua_socket_path = "\(tomlEscaped(luaSocketPath))"
    watch_config = false
    lock_dir = "\(tomlEscaped(lockDirectoryURL.path))"
    develop = false

    [logging]
    enabled = false
    level = "error"
    directory = "\(tomlEscaped(loggingDirectoryURL.path))"

    [agents.calendar]
    enabled = false
    socket_path = "\(tomlEscaped(calendarSocketPath))"

    [agents.network]
    enabled = false
    socket_path = "\(tomlEscaped(networkSocketPath))"
    refresh_interval_seconds = 60
    allow_unauthorized_non_sensitive_fields = false
    """.write(to: configFileURL, atomically: true, encoding: .utf8)
  }

  fileprivate func tomlEscaped(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }
}

/// Terminates one spawned runtime process without risking an indefinite wait in CI.
private func terminate(_ process: Process, gracePeriodNanoseconds: UInt64 = 500_000_000) {
  guard process.isRunning else { return }

  process.terminate()
  let deadline = DispatchTime.now().uptimeNanoseconds + gracePeriodNanoseconds

  while process.isRunning && DispatchTime.now().uptimeNanoseconds < deadline {
    usleep(10_000)
  }

  if process.isRunning {
    kill(process.processIdentifier, SIGKILL)
  }

  process.waitUntilExit()
}
