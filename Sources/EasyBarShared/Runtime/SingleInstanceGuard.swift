import Darwin
import Foundation

public final class SingleInstanceGuard {
  private var lockFileHandle: FileHandle?

  public init() {}

  /// Tries to acquire an exclusive non-blocking lock for the current process.
  public func acquireLock(at path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    let directoryURL = url.deletingLastPathComponent()

    do {
      try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      return false
    }

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

/// Returns the default lock path for one named process inside the given directory.
public func defaultSingleInstanceLockPath(processName: String, directory: String) -> String {
  URL(fileURLWithPath: directory, isDirectory: true)
    .appendingPathComponent("\(processName).lock")
    .path
}
