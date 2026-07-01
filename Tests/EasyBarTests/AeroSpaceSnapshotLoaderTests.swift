import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

final class AeroSpaceSnapshotLoaderTests: XCTestCase {
  func testLoadParsesFormattedJSONWorkspaceAndWindowOutput() {
    let snapshot = loadSnapshot(
      jsonWorkspaces:
        """
        [
          {"workspace": "1", "workspace-is-focused": true, "workspace-is-visible": true},
          {"workspace": "2", "workspace-is-focused": false, "workspace-is-visible": false}
        ]
        """,
      jsonWindows:
        """
        [
          {
            "workspace": "1",
            "app-name": "Safari",
            "app-bundle-path": "/Applications/Safari.app"
          }
        ]
        """,
      jsonFocusedWindow:
        """
        [
          {
            "workspace": "1",
            "app-name": "Safari",
            "app-bundle-path": "/Applications/Safari.app",
            "window-layout": "h_tiles"
          }
        ]
        """
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["1", "2"])
    XCTAssertEqual(snapshot.spaces.map(\.isFocused), [true, false])
    XCTAssertEqual(snapshot.spaces.map(\.isVisible), [true, false])
    XCTAssertEqual(snapshot.spaces[0].apps.map(\.name), ["Safari"])
    XCTAssertEqual(snapshot.spaces[0].apps.map(\.bundlePath), ["/Applications/Safari.app"])
    XCTAssertEqual(snapshot.focusedApp?.name, "Safari")
    XCTAssertEqual(snapshot.focusedApp?.bundlePath, "/Applications/Safari.app")
    XCTAssertEqual(snapshot.focusedLayoutMode, .hTiles)
  }

  func testLoadReturnsEmptySnapshotWhenJSONWorkspaceFieldsAreMissing() {
    let snapshot = loadSnapshot(
      jsonWorkspaces:
        """
        [
          {"workspace": "1"}
        ]
        """,
      jsonWindows: "[]",
      jsonFocusedWindow: "[]"
    )

    XCTAssertEqual(snapshot.spaces, [])
    XCTAssertNil(snapshot.focusedApp)
    XCTAssertEqual(snapshot.focusedLayoutMode, .unknown)
  }

  func testLoadKeepsEmptyWorkspacesInSnapshot() {
    let snapshot = loadSnapshot(
      jsonWorkspaces:
        """
        [
          {"workspace": "1", "workspace-is-focused": true, "workspace-is-visible": true},
          {"workspace": "2", "workspace-is-focused": false, "workspace-is-visible": false}
        ]
        """,
      jsonWindows:
        """
        [
          {
            "workspace": "1",
            "app-name": "Safari",
            "app-bundle-path": "/Applications/Safari.app"
          }
        ]
        """,
      jsonFocusedWindow:
        """
        [
          {
            "workspace": "1",
            "app-name": "Safari",
            "app-bundle-path": "/Applications/Safari.app",
            "window-layout": "h_tiles"
          }
        ]
        """
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["1", "2"])
    XCTAssertEqual(snapshot.spaces[0].apps.map(\.name), ["Safari"])
    XCTAssertEqual(snapshot.spaces[1].apps, [])
    XCTAssertEqual(snapshot.focusedApp?.name, "Safari")
    XCTAssertEqual(snapshot.focusedApp?.bundlePath, "/Applications/Safari.app")
    XCTAssertEqual(snapshot.focusedLayoutMode, .hTiles)
  }

  func testVisibleSpacesRespectsHideEmptyConfiguration() {
    let spaces = [
      SpaceItem(id: "1", name: "1", isFocused: false, isVisible: false, apps: []),
      SpaceItem(id: "2", name: "2", isFocused: true, isVisible: true, apps: []),
      SpaceItem(
        id: "3",
        name: "3",
        isFocused: false,
        isVisible: false,
        apps: [SpaceApp(id: "mail", bundleID: "", name: "Mail", bundlePath: nil)]
      ),
    ]

    XCTAssertEqual(
      SpacesWidgetView.visibleSpaces(spaces, hideEmpty: false).map(\.name),
      ["1", "2", "3"]
    )
    XCTAssertEqual(
      SpacesWidgetView.visibleSpaces(spaces, hideEmpty: true).map(\.name),
      ["2", "3"]
    )
  }

  func testLoadParsesWorkspaceNamesContainingSpaces() {
    let snapshot = loadSnapshot(
      jsonWorkspaces:
        """
        [
          {"workspace": "Work Inbox", "workspace-is-focused": false, "workspace-is-visible": true},
          {"workspace": "Deep Focus", "workspace-is-focused": true, "workspace-is-visible": true}
        ]
        """,
      jsonWindows: "[]",
      jsonFocusedWindow:
        """
        [
          {
            "workspace": "Deep Focus",
            "app-name": "Ghostty",
            "app-bundle-path": "/Applications/Ghostty.app",
            "window-layout": "floating"
          }
        ]
        """
    )

    XCTAssertEqual(snapshot.spaces.map(\.name), ["Work Inbox", "Deep Focus"])
    XCTAssertEqual(snapshot.spaces.map(\.isFocused), [false, true])
    XCTAssertEqual(snapshot.spaces.map(\.isVisible), [true, true])
    XCTAssertEqual(snapshot.focusedLayoutMode, .floating)
  }

  func testLoadDeduplicatesAppsByResolvedIdentity() {
    let snapshot = loadSnapshot(
      jsonWorkspaces:
        """
        [
          {"workspace": "1", "workspace-is-focused": true, "workspace-is-visible": true}
        ]
        """,
      jsonWindows:
        """
        [
          {
            "workspace": "1",
            "app-name": "Safari",
            "app-bundle-path": "/Applications/Safari.app"
          },
          {
            "workspace": "1",
            "app-name": "Safari",
            "app-bundle-path": "/Applications/Safari.app"
          },
          {
            "workspace": "1",
            "app-name": "Safari Technology Preview",
            "app-bundle-path": "/Applications/Safari Technology Preview.app"
          }
        ]
        """,
      jsonFocusedWindow: "[]"
    )

    XCTAssertEqual(
      snapshot.spaces[0].apps.map(\.name),
      ["Safari", "Safari Technology Preview"]
    )
    XCTAssertEqual(
      snapshot.spaces[0].apps.map(\.id),
      ["/Applications/Safari.app", "/Applications/Safari Technology Preview.app"]
    )
  }

  func testLoadUsesFormattedJSONCommandsOnly() {
    var requestedArguments: [[String]] = []

    _ = AeroSpaceSnapshotLoader.load(
      run: { arguments in
        requestedArguments.append(arguments)
        switch arguments {
        case [
          "list-workspaces", "--all", "--json", "--format",
          "%{workspace} %{workspace-is-focused} %{workspace-is-visible}",
        ]:
          return
            """
            [
              {"workspace": "1", "workspace-is-focused": true, "workspace-is-visible": true}
            ]
            """
        case [
          "list-windows", "--all", "--json", "--format",
          "%{workspace} %{app-name} %{app-bundle-path}",
        ]:
          return "[]"
        case [
          "list-windows", "--focused", "--json", "--format",
          "%{workspace} %{app-name} %{app-bundle-path} %{window-layout}",
        ]:
          return "[]"
        default:
          return nil
        }
      },
      resolveAppID: { name, bundlePath in bundlePath ?? name }
    )

    XCTAssertEqual(
      requestedArguments,
      [
        [
          "list-workspaces", "--all", "--json", "--format",
          "%{workspace} %{workspace-is-focused} %{workspace-is-visible}",
        ],
        [
          "list-windows", "--all", "--json", "--format",
          "%{workspace} %{app-name} %{app-bundle-path}",
        ],
        [
          "list-windows", "--focused", "--json", "--format",
          "%{workspace} %{app-name} %{app-bundle-path} %{window-layout}",
        ],
      ]
    )
  }

  private func loadSnapshot(
    jsonWorkspaces: String,
    jsonWindows: String,
    jsonFocusedWindow: String,
    resolveAppID: (String, String?) -> String = { name, bundlePath in bundlePath ?? name }
  ) -> AeroSpaceSnapshot {
    AeroSpaceSnapshotLoader.load(
      run: { arguments in
        switch arguments {
        case [
          "list-workspaces", "--all", "--json", "--format",
          "%{workspace} %{workspace-is-focused} %{workspace-is-visible}",
        ]:
          return jsonWorkspaces
        case [
          "list-windows", "--all", "--json", "--format",
          "%{workspace} %{app-name} %{app-bundle-path}",
        ]:
          return jsonWindows
        case [
          "list-windows", "--focused", "--json", "--format",
          "%{workspace} %{app-name} %{app-bundle-path} %{window-layout}",
        ]:
          return jsonFocusedWindow
        default:
          return nil
        }
      },
      resolveAppID: resolveAppID
    )
  }
}

final class AeroSpaceVersionRequirementTests: XCTestCase {
  func testValidateAcceptsSupportedClientAndServerVersions() throws {
    try AeroSpaceVersionRequirement.validate(
      output:
        """
        aerospace CLI client version: 0.21.1-Beta cfd4eab235b254ff5f1a1b9180a3997ae060162a
        AeroSpace.app server version: 0.21.0-Beta dd6b927a299c3af3e5760c4c3fc6012b984f9e51
        """
    )
  }

  func testValidateRejectsOldClientVersion() {
    XCTAssertThrowsError(
      try AeroSpaceVersionRequirement.validate(
        output:
          """
          aerospace CLI client version: 0.20.0-Beta cfd4eab235b254ff5f1a1b9180a3997ae060162a
          AeroSpace.app server version: 0.21.0-Beta dd6b927a299c3af3e5760c4c3fc6012b984f9e51
          """
      )
    )
  }

  func testValidateRejectsOldServerVersion() {
    XCTAssertThrowsError(
      try AeroSpaceVersionRequirement.validate(
        output:
          """
          aerospace CLI client version: 0.21.0-Beta cfd4eab235b254ff5f1a1b9180a3997ae060162a
          AeroSpace.app server version: 0.20.0-Beta dd6b927a299c3af3e5760c4c3fc6012b984f9e51
          """
      )
    )
  }

  func testValidateRejectsUnparseableVersionOutput() {
    XCTAssertThrowsError(try AeroSpaceVersionRequirement.validate(output: "AeroSpace unknown"))
  }
}

final class AeroSpaceCommandRunnerTests: XCTestCase {
  func testSubscriptionControllerReconnectsWhenProcessExits() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "easybar-aerospace-subscribe-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try """
    #!/bin/sh
    count_file='\(Self.shellQuoted(countURL.path))'
    count="$(cat "$count_file" 2>/dev/null || echo 0)"
    count=$((count + 1))
    echo "$count" > "$count_file"
    exit 3
    """.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: scriptURL.path
    )

    let logger = ProcessLogger(
      label: "easybar.app.services.aerospace.subscribe",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil
    )
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.01, 0.01],
      handleEvent: { _ in }
    )

    controller.start()
    defer { controller.stop() }

    let deadline = Date().addingTimeInterval(1)
    while Date() < deadline {
      let count =
        (try? String(contentsOf: countURL, encoding: .utf8))
        .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
      if count >= 2 {
        return
      }
      Thread.sleep(forTimeInterval: 0.01)
    }

    let count =
      (try? String(contentsOf: countURL, encoding: .utf8))
      .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
    XCTFail("expected subscription process to reconnect, launched \(count) time(s)")
  }

  func testSubscriptionControllerDoesNotReconnectWhenExecutableDisappears() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try """
    #!/bin/sh
    count_file='\(Self.shellQuoted(countURL.path))'
    count="$(cat "$count_file" 2>/dev/null || echo 0)"
    count=$((count + 1))
    echo "$count" > "$count_file"
    rm "$0"
    exit 3
    """.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: scriptURL.path
    )

    let logger = ProcessLogger(
      label: "easybar.app.services.aerospace.subscribe",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil
    )
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: {
        FileManager.default.isExecutableFile(atPath: scriptURL.path) ? scriptURL.path : nil
      }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.01],
      handleEvent: { _ in }
    )

    controller.start()
    defer { controller.stop() }
    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 1))
    Thread.sleep(forTimeInterval: 0.08)

    XCTAssertEqual(Self.launchCount(at: countURL), 1)
  }

  func testSubscriptionControllerAdvancesReconnectBackoffAcrossCrashes() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try Self.writeCountingScript(
      at: scriptURL,
      countURL: countURL,
      body:
        """
        exit 3
        """
    )

    let logURL = directoryURL.appendingPathComponent("process.log")
    let logger = Self.makeFileLogger(logURL: logURL)
    defer { logger.configureFileLogging(enabled: false, path: "") }
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.01, 0.05],
      handleEvent: { _ in }
    )

    controller.start()
    defer { controller.stop() }
    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 3))
    logger.configureFileLogging(enabled: false, path: "")

    let output = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertTrue(output.contains("delay=0.01"))
    XCTAssertTrue(output.contains("delay=0.05"))
  }

  func testSubscriptionControllerResetsReconnectBackoffAfterEventLine() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try Self.writeCountingScript(
      at: scriptURL,
      countURL: countURL,
      body:
        """
        if [ "$count" -eq 2 ]; then
          echo '{"_event":"focused-workspace-changed"}'
        fi
        exit 3
        """
    )

    let logURL = directoryURL.appendingPathComponent("process.log")
    let logger = Self.makeFileLogger(logURL: logURL)
    defer { logger.configureFileLogging(enabled: false, path: "") }
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.01, 0.05],
      handleEvent: { _ in }
    )

    controller.start()
    defer { controller.stop() }
    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 4))
    logger.configureFileLogging(enabled: false, path: "")

    let output = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertGreaterThanOrEqual(output.components(separatedBy: "delay=0.01").count - 1, 2)
  }

  func testSubscriptionControllerStopCancelsPendingReconnect() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try Self.writeCountingScript(
      at: scriptURL,
      countURL: countURL,
      body:
        """
        exit 3
        """
    )

    let logger = ProcessLogger(
      label: "easybar.app.services.aerospace.subscribe",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil
    )
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.2],
      handleEvent: { _ in }
    )

    controller.start()
    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 1))
    controller.stop()
    Thread.sleep(forTimeInterval: 0.3)

    XCTAssertEqual(Self.launchCount(at: countURL), 1)
  }

  func testRunLogsStderrWhenCommandExitsNonZero() throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "easybar-aerospace-runner-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try """
    #!/bin/sh
    echo 'bad format token' >&2
    exit 2
    """.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: scriptURL.path
    )

    let logURL = directoryURL.appendingPathComponent("process.log")
    let logger = ProcessLogger(
      label: "easybar.app.services.aerospace.commands",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil
    )
    logger.configureFileLogging(enabled: true, path: logURL.path)
    defer { logger.configureFileLogging(enabled: false, path: "") }

    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )

    _ = runner.run(arguments: ["list-workspaces", "--all", "--json"])
    logger.configureFileLogging(enabled: false, path: "")

    let output = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertTrue(output.contains("aerospace command exited"))
    XCTAssertTrue(output.contains("status=2"))
    XCTAssertTrue(output.contains("stderr_bytes=16"))
  }

  private static func shellQuoted(_ value: String) -> String {
    value.replacingOccurrences(of: "'", with: "'\\''")
  }

  private static func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "easybar-aerospace-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
  }

  private static func writeCountingScript(
    at scriptURL: URL,
    countURL: URL,
    body: String
  ) throws {
    try """
    #!/bin/sh
    count_file='\(shellQuoted(countURL.path))'
    count="$(cat "$count_file" 2>/dev/null || echo 0)"
    count=$((count + 1))
    echo "$count" > "$count_file"
    \(body)
    """.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: scriptURL.path
    )
  }

  private static func launchCount(at countURL: URL) -> Int {
    (try? String(contentsOf: countURL, encoding: .utf8))
      .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
  }

  private static func waitForLaunchCount(
    at countURL: URL,
    minimum: Int,
    timeout: TimeInterval = 1
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if launchCount(at: countURL) >= minimum {
        return true
      }
      Thread.sleep(forTimeInterval: 0.01)
    }
    return false
  }

  private static func makeFileLogger(logURL: URL) -> ProcessLogger {
    let logger = ProcessLogger(
      label: "easybar.app.services.aerospace.subscribe",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil
    )
    logger.configureFileLogging(enabled: true, path: logURL.path)
    return logger
  }
}
