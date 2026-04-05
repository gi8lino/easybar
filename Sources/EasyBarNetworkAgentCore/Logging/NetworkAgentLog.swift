import EasyBarShared
import Foundation

public let networkAgentLog = ProcessLogger(label: "easybar-network-agent")

/// Returns the network agent log path inside one logging directory.
public func networkAgentLogPath(in directory: String) -> String {
  URL(fileURLWithPath: directory)
    .appendingPathComponent("network-agent.out")
    .path
}
