import Darwin
import Foundation

/// Low-level helpers for building `posix_spawn` inputs.
enum PosixSpawnSupport {
  /// Initializes one `posix_spawn_file_actions_t`.
  static func initializeFileActions(_ fileActions: inout posix_spawn_file_actions_t?) throws {
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
  static func initializeSpawnAttributes(_ attributes: inout posix_spawnattr_t?) throws {
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

  /// Configures the child to become leader of a dedicated process group.
  static func configureDedicatedProcessGroup(
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

  /// Creates one null-terminated C string vector suitable for `posix_spawn`.
  static func makeCStringVector(
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
  static func freeCStringVector(
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
  static func addDup2Action(
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
  static func addCloseAction(
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
}
