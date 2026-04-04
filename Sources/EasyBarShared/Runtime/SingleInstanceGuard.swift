import Darwin
import Foundation

public final class SingleInstanceGuard {
  private var lockFileHandle: FileHandle?

  public init() {}

  /// Tries to acquire an exclusive non-blocking lock for the current process.
  public func acquireLock(at path: String) -> Bool {
    FileManager.default.createFile(atPath: path, contents: nil)

    guard let handle = FileHandle(forWritingAtPath: path) else {
      return false
    }

    let result = flock(handle.fileDescriptor, LOCK_EX | LOCK_NB)
    guard result == 0 else {
      handle.closeFile()
      return false
    }

    lockFileHandle = handle
    return true
  }
}

/// Returns the default lock path for one named process.
public func defaultSingleInstanceLockPath(processName: String) -> String {
  FileManager.default.temporaryDirectory
    .appendingPathComponent("\(processName).lock")
    .path
}
