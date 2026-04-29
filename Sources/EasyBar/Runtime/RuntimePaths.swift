import EasyBarShared
import Foundation

/// Returns the EasyBar log path inside one logging directory.
func easyBarLogPath(in directory: String) -> String {
  URL(fileURLWithPath: directory)
    .appendingPathComponent("easybar.out")
    .path
}
