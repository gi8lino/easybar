import Darwin
import Foundation

extension LuaProcessController {

  /// Resolves the launch inputs for one Lua runtime process.
  func launchContext() -> LaunchContext? {
    guard let runtimePath = resolvedRuntimePath() else { return nil }

    return LaunchContext(
      runtimePath: runtimePath,
      luaPath: Config.shared.luaPath,
      widgetsPath: Config.shared.widgetsPath,
      environment: Config.shared.appSection.environment
    )
  }

  /// Resolves the bundled Lua runtime script path.
  func resolvedRuntimePath() -> String? {
    guard let runtime = Bundle.module.url(forResource: "runtime", withExtension: "lua") else {
      easybarLog.error("runtime.lua not found")
      return nil
    }

    return runtime.path
  }

  /// Logs one Lua runtime launch request.
  func logLaunch(context: LaunchContext) {
    easybarLog.debug("starting lua runtime")
    easybarLog.debug("lua binary: \(context.luaPath)")
    easybarLog.debug("lua script: \(context.runtimePath)")
    easybarLog.debug("widgets path: \(context.widgetsPath)")
    easybarLog.debug("lua env keys: \(context.environment.keys.sorted())")
  }

  /// Spawns one Lua runtime process with a dedicated process group assigned at spawn time.
  ///
  /// The child becomes the leader of its own process group immediately, which avoids the
  /// racy post-launch `setpgid` handoff and guarantees subtree-isolated signal delivery.
  func spawnProcess(context: LaunchContext, pipes: LaunchPipes) throws -> Int32 {
    var fileActions: posix_spawn_file_actions_t?
    var attributes: posix_spawnattr_t?

    try initializeFileActions(&fileActions)
    defer {
      if fileActions != nil {
        posix_spawn_file_actions_destroy(&fileActions)
      }
    }

    try initializeSpawnAttributes(&attributes)
    defer {
      if attributes != nil {
        posix_spawnattr_destroy(&attributes)
      }
    }

    try configureChildStandardStreams(
      fileActions: &fileActions,
      pipes: pipes
    )

    try configureDedicatedProcessGroup(attributes: &attributes)

    let argv = try makeArgumentVector(
      executablePath: context.luaPath,
      runtimePath: context.runtimePath,
      widgetsPath: context.widgetsPath
    )
    defer { freeCStringVector(argv) }

    let envp = try makeEnvironmentVector(overrides: context.environment)
    defer { freeCStringVector(envp) }

    var pid: pid_t = 0

    let spawnResult = context.luaPath.withCString { executablePath in
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
            "posix_spawn failed for lua runtime executable=\(context.luaPath) errno=\(spawnResult)"
        ]
      )
    }

    closeParentPipeEndsAfterSuccessfulSpawn(pipes)

    return pid
  }

  /// Installs exit observation for the spawned Lua child.
  func installTerminationSource(for pid: Int32) {
    let previousSource = withLock { () -> DispatchSourceProcess? in
      let previousSource = terminationSource
      terminationSource = nil
      return previousSource
    }

    previousSource?.cancel()

    let source = DispatchSource.makeProcessSource(
      identifier: pid,
      eventMask: .exit,
      queue: .global(qos: .utility)
    )

    source.setEventHandler { [weak self] in
      self?.handleTermination(pid: pid)
    }

    source.resume()
    withLock {
      terminationSource = source
    }
  }

  /// Handles Lua process termination and related cleanup logging.
  func handleTermination(pid: Int32) {
    cancelForcedKillWorkItem()

    var rawStatus: Int32 = 0
    let waitResult = waitpid(pid, &rawStatus, 0)

    let status: Int32
    if waitResult == pid {
      status = normalizedTerminationStatus(from: rawStatus)
    } else {
      let code = errno
      easybarLog.warn("waitpid failed for lua runtime pid=\(pid) errno=\(code)")
      status = 1
    }

    clearTrackedProcessIfMatching(pid: pid)
    logTerminationStatus(status, processIdentifier: pid)
  }

  /// Converts a raw `waitpid` status into the log/status shape used elsewhere.
  ///
  /// For normal exit the low 7 bits are zero and the exit code is stored in the high byte.
  /// For signal termination the low 7 bits contain the terminating signal number.
  func normalizedTerminationStatus(from rawStatus: Int32) -> Int32 {
    let signal = rawStatus & 0x7f

    if signal == 0 {
      return (rawStatus >> 8) & 0xff
    }

    return signal
  }

  /// Logs one Lua runtime termination status.
  func logTerminationStatus(_ status: Int32, processIdentifier: Int32) {
    guard status != 0 else {
      easybarLog.info("lua runtime terminated pid=\(processIdentifier) status=\(status)")
      return
    }

    easybarLog.warn("lua runtime terminated pid=\(processIdentifier) status=\(status)")
  }

  /// Initializes one `posix_spawn_file_actions_t`.
  private func initializeFileActions(_ fileActions: inout posix_spawn_file_actions_t?) throws {
    fileActions = nil

    let result = posix_spawn_file_actions_init(&fileActions)
    guard result == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(result),
        userInfo: [
          NSLocalizedDescriptionKey: "posix_spawn_file_actions_init failed errno=\(result)"
        ]
      )
    }
  }

  /// Initializes one `posix_spawnattr_t`.
  private func initializeSpawnAttributes(_ attributes: inout posix_spawnattr_t?) throws {
    attributes = nil

    let result = posix_spawnattr_init(&attributes)
    guard result == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(result),
        userInfo: [
          NSLocalizedDescriptionKey: "posix_spawnattr_init failed errno=\(result)"
        ]
      )
    }
  }

  /// Configures stdin/stdout/stderr redirection for the Lua child.
  private func configureChildStandardStreams(
    fileActions: inout posix_spawn_file_actions_t?,
    pipes: LaunchPipes
  ) throws {
    try addDup2Action(
      fileActions: &fileActions,
      sourceFileDescriptor: pipes.input.fileHandleForReading.fileDescriptor,
      destinationFileDescriptor: STDIN_FILENO
    )

    try addDup2Action(
      fileActions: &fileActions,
      sourceFileDescriptor: pipes.output.fileHandleForWriting.fileDescriptor,
      destinationFileDescriptor: STDOUT_FILENO
    )

    try addDup2Action(
      fileActions: &fileActions,
      sourceFileDescriptor: pipes.error.fileHandleForWriting.fileDescriptor,
      destinationFileDescriptor: STDERR_FILENO
    )

    try addCloseAction(
      fileActions: &fileActions,
      fileDescriptor: pipes.input.fileHandleForWriting.fileDescriptor
    )

    try addCloseAction(
      fileActions: &fileActions,
      fileDescriptor: pipes.output.fileHandleForReading.fileDescriptor
    )

    try addCloseAction(
      fileActions: &fileActions,
      fileDescriptor: pipes.error.fileHandleForReading.fileDescriptor
    )
  }

  /// Configures the child to become leader of a dedicated process group.
  ///
  /// With `POSIX_SPAWN_SETPGROUP` and pgroup `0`, the spawned child becomes the leader
  /// of its own process group at spawn time.
  private func configureDedicatedProcessGroup(
    attributes: inout posix_spawnattr_t?
  ) throws {
    let flags = Int16(POSIX_SPAWN_SETPGROUP)

    let flagsResult = posix_spawnattr_setflags(&attributes, flags)
    guard flagsResult == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(flagsResult),
        userInfo: [
          NSLocalizedDescriptionKey: "posix_spawnattr_setflags failed errno=\(flagsResult)"
        ]
      )
    }

    let pgroupResult = posix_spawnattr_setpgroup(&attributes, 0)
    guard pgroupResult == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(pgroupResult),
        userInfo: [
          NSLocalizedDescriptionKey: "posix_spawnattr_setpgroup failed errno=\(pgroupResult)"
        ]
      )
    }
  }

  /// Builds the argv vector for the spawned Lua runtime.
  private func makeArgumentVector(
    executablePath: String,
    runtimePath: String,
    widgetsPath: String
  ) throws -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> {
    try makeCStringVector([
      executablePath,
      runtimePath,
      widgetsPath,
    ])
  }

  /// Builds the environment vector inherited by the Lua runtime.
  private func makeEnvironmentVector(
    overrides: [String: String]
  ) throws -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
  {
    var environment = ProcessInfo.processInfo.environment
    overrides.forEach { key, value in
      environment[key] = value
    }
    environment["PATH"] = resolvedRuntimePATH(from: environment, overrides: overrides)

    let flattenedEnvironment = environment
      .map { "\($0.key)=\($0.value)" }
      .sorted()

    return try makeCStringVector(flattenedEnvironment)
  }

  /// Returns one predictable PATH for widget shell commands, without requiring shell startup files.
  private func resolvedRuntimePATH(
    from environment: [String: String],
    overrides: [String: String]
  ) -> String {
    if let configuredPath = overrides["PATH"], !configuredPath.isEmpty {
      return configuredPath
    }

    let inheritedPath = environment["PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !inheritedPath.isEmpty {
      return inheritedPath
    }

    return defaultRuntimePATH()
  }

  /// Returns one conservative default PATH for GUI-launched widget subprocesses.
  private func defaultRuntimePATH() -> String {
    "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  }

  /// Creates one null-terminated C string vector suitable for `posix_spawn`.
  private func makeCStringVector(
    _ values: [String]
  ) throws -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> {
    let buffer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(
      capacity: values.count + 1
    )

    for (index, value) in values.enumerated() {
      guard let duplicated = strdup(value) else {
        for previousIndex in 0..<index {
          free(buffer[previousIndex])
        }
        buffer.deallocate()

        throw NSError(
          domain: NSPOSIXErrorDomain,
          code: Int(ENOMEM),
          userInfo: [
            NSLocalizedDescriptionKey: "strdup failed while building spawn arguments"
          ]
        )
      }

      buffer[index] = duplicated
    }

    buffer[values.count] = nil
    return buffer
  }

  /// Frees one previously allocated C string vector.
  private func freeCStringVector(
    _ vector: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
  ) {
    var index = 0

    while let value = vector[index] {
      free(value)
      index += 1
    }

    vector.deallocate()
  }

  /// Adds one `dup2` file action.
  private func addDup2Action(
    fileActions: inout posix_spawn_file_actions_t?,
    sourceFileDescriptor: Int32,
    destinationFileDescriptor: Int32
  ) throws {
    let result = posix_spawn_file_actions_adddup2(
      &fileActions,
      sourceFileDescriptor,
      destinationFileDescriptor
    )

    guard result == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(result),
        userInfo: [
          NSLocalizedDescriptionKey:
            "posix_spawn_file_actions_adddup2 failed src=\(sourceFileDescriptor) dst=\(destinationFileDescriptor) errno=\(result)"
        ]
      )
    }
  }

  /// Adds one close file action.
  private func addCloseAction(
    fileActions: inout posix_spawn_file_actions_t?,
    fileDescriptor: Int32
  ) throws {
    let result = posix_spawn_file_actions_addclose(&fileActions, fileDescriptor)

    guard result == 0 else {
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(result),
        userInfo: [
          NSLocalizedDescriptionKey:
            "posix_spawn_file_actions_addclose failed fd=\(fileDescriptor) errno=\(result)"
        ]
      )
    }
  }

  /// Closes the child-side pipe ends in the parent after a successful spawn.
  private func closeParentPipeEndsAfterSuccessfulSpawn(_ pipes: LaunchPipes) {
    try? pipes.input.fileHandleForReading.close()
    try? pipes.output.fileHandleForWriting.close()
    try? pipes.error.fileHandleForWriting.close()
  }

  /// Closes all launch pipes after a failed spawn attempt.
  func closeLaunchPipesAfterFailedSpawn(_ pipes: LaunchPipes) {
    try? pipes.input.fileHandleForReading.close()
    try? pipes.input.fileHandleForWriting.close()
    try? pipes.output.fileHandleForReading.close()
    try? pipes.output.fileHandleForWriting.close()
    try? pipes.error.fileHandleForReading.close()
    try? pipes.error.fileHandleForWriting.close()
  }
}
