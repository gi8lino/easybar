import Darwin
import Foundation

public enum SingleInstanceAcquireResult: Equatable {
  case acquired
  case alreadyRunning
  case failed(String)
}

public final class SingleInstanceGuard {
  private var lockFileHandle: FileHandle?

  public init() {}

  deinit {
    lockFileHandle?.closeFile()
  }

  /// Tries to acquire an exclusive non-blocking lock for the current process.
  @discardableResult
  public func acquireLock(at path: String) -> SingleInstanceAcquireResult {
    let url = URL(fileURLWithPath: path)
    let directoryURL = url.deletingLastPathComponent()

    do {
      try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      return .failed("create_directory_failed:\(error)")
    }

    let fd = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard fd >= 0 else {
      return .failed("open_failed:\(String(cString: strerror(errno)))")
    }

    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
      let lockError = errno
      close(fd)

      if lockError == EWOULDBLOCK {
        return .alreadyRunning
      }

      return .failed("lock_failed:\(String(cString: strerror(lockError)))")
    }

    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)

    if let data = "\(getpid())\n".data(using: .utf8) {
      do {
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: data)
        try handle.synchronize()
      } catch {
        // Keep the lock even if PID writing fails.
      }
    }

    lockFileHandle?.closeFile()
    lockFileHandle = handle
    return .acquired
  }
}

/// Returns the default lock path for one named process.
public func defaultSingleInstanceLockPath(processName: String, directory: String? = nil) -> String {
  let baseDirectory =
    directory?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    ? NSString(string: directory!).expandingTildeInPath
    : FileManager.default.temporaryDirectory.path

  return URL(fileURLWithPath: baseDirectory, isDirectory: true)
    .appendingPathComponent("\(processName).lock")
    .path
}
