import Darwin

/// Stable process-termination reason shared by all EasyBar process owners.
public enum ProcessTerminationStatus: Equatable, Sendable {
  case exited(code: Int32)
  case signaled(signal: Int32)
  case unknown(status: Int32)
  case reapFailed(errno: Int32)

  /// Shell-compatible status used by command APIs.
  public var shellExitStatus: Int32 {
    switch self {
    case .exited(let code):
      return code
    case .signaled(let signal):
      return 128 + signal
    case .unknown, .reapFailed:
      return 1
    }
  }
}

/// One blocking or nonblocking `waitpid` observation.
public enum ProcessWaitObservation: Equatable, Sendable {
  case running
  case terminated(rawStatus: Int32, reason: ProcessTerminationStatus)
  case failed(errno: Int32)
}

/// Centralized `waitpid` retry and Darwin wait-status decoding.
public enum ProcessWaitSupport {
  /// Waits for one child using the supplied `waitpid` options.
  public static func wait(
    processIdentifier: pid_t,
    options: Int32 = 0
  ) -> ProcessWaitObservation {
    var status: Int32 = 0

    while true {
      errno = 0
      let result = waitpid(processIdentifier, &status, options)
      let errnoValue = errno

      if result < 0, errnoValue == EINTR {
        continue
      }
      if result == 0 {
        return .running
      }
      if result == processIdentifier {
        return .terminated(rawStatus: status, reason: decode(status: status))
      }
      return .failed(errno: errnoValue)
    }
  }

  /// Decodes one raw Darwin wait status.
  public static func decode(status: Int32) -> ProcessTerminationStatus {
    let code = status & 0x7f
    if code == 0 {
      return .exited(code: (status >> 8) & 0xff)
    }
    if code != 0x7f {
      return .signaled(signal: code)
    }
    return .unknown(status: status)
  }
}
