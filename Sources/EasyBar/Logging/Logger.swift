import EasyBarShared
import Foundation

let easybarLog = ProcessLogger(label: "easybar")

/// Returns the EasyBar log path inside one logging directory.
func easyBarLogPath(in directory: String) -> String {
  URL(fileURLWithPath: directory)
    .appendingPathComponent("easybar.out")
    .path
}
