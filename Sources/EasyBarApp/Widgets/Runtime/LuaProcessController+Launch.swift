import Darwin
import EasyBarShared
import Foundation

extension LuaProcessController {
  /// Resolves the launch inputs for one Lua runtime process.
  func launchContext(config: ConfigSnapshot) -> LaunchContext? {
    guard let runtimePath = resolvedRuntimePath() else { return nil }
    guard let runtimeAgentPath = resolvedRuntimeAgentPath() else { return nil }

    return LaunchContext(
      runtimeAgentPath: runtimeAgentPath,
      runtimePath: runtimePath,
      luaPath: config.app.luaPath,
      luaSocketPath: config.app.luaSocketPath,
      widgetsPath: config.app.widgetsPath,
      defaultCommandTimeoutSeconds: config.app.luaCommandLimits.timeoutSeconds,
      defaultCommandMaxOutputBytes: config.app.luaCommandLimits.maxOutputBytes,
      widgetFiles: resolvedWidgetFiles(in: config.app.widgetsPath),
      environment: luaRuntimeEnvironment(config: config)
    )
  }

  /// Resolves the bundled Lua runtime script path.
  func resolvedRuntimePath() -> String? {
    guard let runtime = AppResourceLocator.url(forResource: "runtime", withExtension: "lua") else {
      logger.error("runtime.lua not found")
      return nil
    }

    return runtime.path
  }

  /// Resolves the bundled Lua runtime agent executable path.
  func resolvedRuntimeAgentPath() -> String? {
    let fileManager = FileManager.default

    if let executableURL = Bundle.main.executableURL {
      let siblingPath =
        executableURL
        .deletingLastPathComponent()
        .appendingPathComponent("EasyBarLuaRuntime")
        .path

      if fileManager.isExecutableFile(atPath: siblingPath) {
        return siblingPath
      }
    }

    let buildCandidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(".build", isDirectory: true)
      .appendingPathComponent("debug", isDirectory: true)
      .appendingPathComponent("EasyBarLuaRuntime")
      .path

    if fileManager.isExecutableFile(atPath: buildCandidate) {
      return buildCandidate
    }

    logger.error("EasyBarLuaRuntime not found")
    return nil
  }

  /// Returns the sorted Lua widget filenames present in the configured widget directory.
  func resolvedWidgetFiles(in widgetsPath: String) -> [String] {
    let widgetsURL = URL(fileURLWithPath: widgetsPath, isDirectory: true)

    guard
      let files = try? FileManager.default.contentsOfDirectory(
        at: widgetsURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    return
      files
      .filter { url in
        guard url.pathExtension == "lua" else { return false }

        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
      }
      .map(\.lastPathComponent)
      .sorted()
  }

  /// Logs one Lua runtime launch request.
  func logLaunch(context: LaunchContext) {
    logger.debug("starting lua runtime")
    logger.debug("lua runtime agent", .field("path", context.runtimeAgentPath))
    logger.debug("lua binary", .field("path", context.luaPath))
    logger.debug("lua socket", .field("path", context.luaSocketPath))
    logger.debug("lua script", .field("path", context.runtimePath))
    logger.debug("widgets path", .field("path", context.widgetsPath))
    logger.debug("widget files", .field("count", context.widgetFiles.count))
    logger.debug("lua env keys", .field("keys", context.environment.keys.sorted()))
  }

  /// Spawns one Lua runtime process with a dedicated process group assigned at spawn time.
  func spawnProcess(context: LaunchContext, resources: LaunchResources) throws -> Int32 {
    var fileActions: posix_spawn_file_actions_t?
    var attributes: posix_spawnattr_t?

    try PosixSpawnSupport.initializeFileActions(&fileActions)
    defer {
      if fileActions != nil {
        posix_spawn_file_actions_destroy(&fileActions)
      }
    }

    try PosixSpawnSupport.initializeSpawnAttributes(&attributes)
    defer {
      if attributes != nil {
        posix_spawnattr_destroy(&attributes)
      }
    }

    try configureChildStandardStreams(
      fileActions: &fileActions,
      resources: resources
    )

    try PosixSpawnSupport.configureDedicatedProcessGroup(attributes: &attributes)

    let argv = try makeArgumentVector(
      executablePath: context.runtimeAgentPath,
      socketPath: context.luaSocketPath,
      luaPath: context.luaPath,
      runtimePath: context.runtimePath,
      widgetsPath: context.widgetsPath,
      defaultCommandTimeoutSeconds: context.defaultCommandTimeoutSeconds,
      defaultCommandMaxOutputBytes: context.defaultCommandMaxOutputBytes,
      widgetFiles: context.widgetFiles
    )
    defer { PosixSpawnSupport.freeCStringVector(argv) }

    let envp = try makeEnvironmentVector(overrides: context.environment)
    defer { PosixSpawnSupport.freeCStringVector(envp) }

    var pid: pid_t = 0

    let spawnResult = context.runtimeAgentPath.withCString { executablePath in
      posix_spawn(
        &pid,
        executablePath,
        &fileActions,
        &attributes,
        argv,
        envp
      )
    }

    guard spawnResult == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(spawnResult),
        userInfo: [
          NSLocalizedDescriptionKey:
            "posix_spawn failed for lua runtime agent=\(context.runtimeAgentPath) errno=\(spawnResult)"
        ]
      )
    }

    closeParentPipeEndsAfterSuccessfulSpawn(resources)

    return pid
  }

  /// Installs exit observation for the spawned Lua child.
  func installTerminationSource(for pid: Int32) {
    let previousTask = withLock { () -> Task<Void, Never>? in
      let previousTask = terminationTask
      terminationTask = nil
      return previousTask
    }

    previousTask?.cancel()

    let task = DetachedTask.run(priority: .utility) { [weak self] in
      guard let self else { return }
      let waitResult = self.waitForRuntimeProcessExit(pid: pid)
      guard !Task.isCancelled else { return }
      self.handleTermination(
        pid: pid,
        waitResult: waitResult.result,
        status: waitResult.status,
        errnoValue: waitResult.errnoValue
      )
    }

    withLock {
      terminationTask = task
    }
  }

  /// Waits for the Lua runtime process to exit and retries interrupted waits.
  private func waitForRuntimeProcessExit(pid: Int32) -> (
    result: Int32,
    status: Int32,
    errnoValue: Int32
  ) {
    var status: Int32 = 0

    while true {
      errno = 0
      let waitResult = waitpid(pid, &status, 0)
      let errnoValue = errno

      if waitResult < 0, errnoValue == EINTR {
        continue
      }

      return (waitResult, status, errnoValue)
    }
  }

  /// Handles one observed Lua runtime termination.
  func handleTermination(pid: Int32, waitResult: Int32, status: Int32, errnoValue: Int32) {
    let reason: Termination.Reason

    if waitResult == pid {
      logTermination(pid: pid, status: status)
      reason = terminationReason(status: status)
    } else {
      if shouldLogReapFailure(waitResult: waitResult, errnoValue: errnoValue) {
        logger.warn(
          "failed to reap lua runtime",
          .field("pid", pid),
          .field("errno", errnoValue)
        )
      }
      reason = .reapFailed(errno: errnoValue)
    }

    guard let delivery = clearTrackedProcessIfMatching(pid: pid) else { return }
    delivery.handler?(
      Termination(
        processIdentifier: pid,
        reason: reason,
        wasRequested: delivery.wasRequested
      )
    )
  }

  /// Converts one Darwin wait status into a stable termination reason.
  func terminationReason(status: Int32) -> Termination.Reason {
    if waitStatusExited(status) {
      return .exited(code: waitStatusExitCode(status))
    }

    if waitStatusSignaled(status) {
      return .signaled(signal: waitStatusTerminationSignal(status))
    }

    return .unknown(status: status)
  }

  /// Returns whether a failed reap should be logged for the observed child process.
  private func shouldLogReapFailure(waitResult: Int32, errnoValue: Int32) -> Bool {
    return waitResult < 0 && errnoValue != ECHILD
  }

  /// Logs one Lua runtime termination status.
  private func logTermination(pid processIdentifier: Int32, status: Int32) {
    if waitStatusExited(status) {
      let exitCode = waitStatusExitCode(status)

      if exitCode == 0 {
        logger.debug(
          "lua runtime exited",
          .field("pid", processIdentifier),
          .field("code", exitCode)
        )
      } else {
        logger.warn(
          "lua runtime exited",
          .field("pid", processIdentifier),
          .field("code", exitCode)
        )
      }

      return
    }

    if waitStatusSignaled(status) {
      logger.warn(
        "lua runtime terminated by signal",
        .field("pid", processIdentifier),
        .field("signal", waitStatusTerminationSignal(status))
      )
      return
    }

    logger.warn(
      "lua runtime terminated",
      .field("pid", processIdentifier),
      .field("status", status)
    )
  }

  /// Returns the low wait-status byte used by Darwin wait macros.
  private func waitStatusCode(_ status: Int32) -> Int32 {
    return status & 0x7f
  }

  /// Returns whether one wait status represents normal process exit.
  private func waitStatusExited(_ status: Int32) -> Bool {
    return waitStatusCode(status) == 0
  }

  /// Returns the process exit code from one wait status.
  private func waitStatusExitCode(_ status: Int32) -> Int32 {
    return (status >> 8) & 0xff
  }

  /// Returns whether one wait status represents signal termination.
  private func waitStatusSignaled(_ status: Int32) -> Bool {
    let code = waitStatusCode(status)
    return code != 0x7f && code != 0
  }

  /// Returns the terminating signal from one wait status.
  private func waitStatusTerminationSignal(_ status: Int32) -> Int32 {
    return waitStatusCode(status)
  }

  /// Configures stderr redirection for the Lua child launcher.
  private func configureChildStandardStreams(
    fileActions: inout posix_spawn_file_actions_t?,
    resources: LaunchResources
  ) throws {
    try PosixSpawnSupport.addDup2Action(
      fileActions: &fileActions,
      sourceFileDescriptor: resources.error.fileHandleForWriting.fileDescriptor,
      destinationFileDescriptor: STDERR_FILENO
    )

    try PosixSpawnSupport.addCloseAction(
      fileActions: &fileActions,
      fileDescriptor: resources.error.fileHandleForReading.fileDescriptor
    )
  }

  /// Builds the argv vector for the spawned Lua runtime.
  private func makeArgumentVector(
    executablePath: String,
    socketPath: String,
    luaPath: String,
    runtimePath: String,
    widgetsPath: String,
    defaultCommandTimeoutSeconds: TimeInterval,
    defaultCommandMaxOutputBytes: Int,
    widgetFiles: [String]
  ) throws -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> {
    try PosixSpawnSupport.makeCStringVector(
      [
        executablePath,
        socketPath,
        luaPath,
        runtimePath,
        widgetsPath,
        String(defaultCommandTimeoutSeconds),
        String(defaultCommandMaxOutputBytes),
      ] + widgetFiles
    )
  }

  /// Builds the environment vector inherited by the Lua runtime.
  private func makeEnvironmentVector(
    overrides: [String: String]
  ) throws -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> {
    var environment = ProcessInfo.processInfo.environment

    for (key, value) in overrides {
      environment[key] = value
    }

    let flattenedEnvironment =
      environment
      .map { "\($0.key)=\($0.value)" }
      .sorted()

    return try PosixSpawnSupport.makeCStringVector(flattenedEnvironment)
  }

  /// Closes the child-side pipe ends in the parent after a successful spawn.
  private func closeParentPipeEndsAfterSuccessfulSpawn(_ resources: LaunchResources) {
    try? resources.error.fileHandleForWriting.close()
  }

  /// Closes all launch resources after a failed spawn attempt.
  func closeLaunchResourcesAfterFailedSpawn(_ resources: LaunchResources) {
    try? resources.error.fileHandleForReading.close()
    try? resources.error.fileHandleForWriting.close()
  }

  /// Returns the Lua runtime environment with app config and resolved theme values.
  private func luaRuntimeEnvironment(config: ConfigSnapshot) -> [String: String] {
    config.app.environment
      .merging(config.luaThemeEnvironment()) {
        _, themeValue in themeValue
      }
  }
}
