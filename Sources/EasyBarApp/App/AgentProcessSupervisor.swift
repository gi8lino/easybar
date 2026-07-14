import EasyBarShared
import Foundation

/// Owns bundled helper-agent processes when EasyBar runs from a packaged app bundle.
@MainActor
final class AgentProcessSupervisor {
  private struct Agent {
    let name: String
    let executableURL: URL
    var process: Process?
    var restartGeneration: UInt64 = 0
  }

  private let logger: ProcessLogger
  private var agents: [String: Agent] = [:]
  private var enabledAgentIDs: Set<String> = []
  private var stopping = false

  init(logger: ProcessLogger) {
    self.logger = logger
    guard let contentsURL = Bundle.main.bundleURL.appendingPathComponent("Contents") as URL? else {
      return
    }
    let loginItems = contentsURL.appendingPathComponent("Library/LoginItems", isDirectory: true)
    register("calendar", appName: "EasyBarCalendarAgent", in: loginItems)
    register("network", appName: "EasyBarNetworkAgent", in: loginItems)
  }

  var managesBundledAgents: Bool { !agents.isEmpty }

  func start(calendarEnabled: Bool, networkEnabled: Bool) {
    stopping = false
    update(calendarEnabled: calendarEnabled, networkEnabled: networkEnabled)
  }

  func update(calendarEnabled: Bool, networkEnabled: Bool) {
    enabledAgentIDs = Set(
      [("calendar", calendarEnabled), ("network", networkEnabled)].compactMap { id, enabled in
        enabled ? id : nil
      }
    )
    for id in agents.keys.sorted() {
      if enabledAgentIDs.contains(id) {
        launch(id)
      } else {
        agents[id]?.restartGeneration &+= 1
        agents[id]?.process?.terminate()
        agents[id]?.process = nil
      }
    }
  }

  func stop() {
    stopping = true
    for id in agents.keys {
      agents[id]?.restartGeneration &+= 1
      agents[id]?.process?.terminate()
      agents[id]?.process = nil
    }
  }

  private func register(_ id: String, appName: String, in directory: URL) {
    let executable =
      directory
      .appendingPathComponent("\(appName).app/Contents/MacOS", isDirectory: true)
      .appendingPathComponent(appName)
    guard FileManager.default.isExecutableFile(atPath: executable.path) else { return }
    agents[id] = Agent(name: appName, executableURL: executable)
  }

  private func launch(_ id: String) {
    guard !stopping, enabledAgentIDs.contains(id), var agent = agents[id], agent.process == nil
    else { return }
    let process = Process()
    process.executableURL = agent.executableURL
    process.currentDirectoryURL = Bundle.main.bundleURL.deletingLastPathComponent()
    process.terminationHandler = { [weak self] process in
      Task { @MainActor [weak self] in self?.handleExit(id, status: process.terminationStatus) }
    }
    do {
      try process.run()
      agent.process = process
      agents[id] = agent
      logger.info("bundled agent launched", .field("agent", agent.name))
    } catch {
      logger.error("bundled agent launch failed", .field("agent", agent.name), .field("error", "\(error)"))
    }
  }

  private func handleExit(_ id: String, status: Int32) {
    guard var agent = agents[id] else { return }
    agent.process = nil
    agent.restartGeneration &+= 1
    let generation = agent.restartGeneration
    agents[id] = agent
    guard !stopping, enabledAgentIDs.contains(id) else { return }
    logger.warn("bundled agent exited; scheduling restart", .field("agent", agent.name), .field("status", status))
    Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(1))
      guard let self, self.agents[id]?.restartGeneration == generation else { return }
      self.launch(id)
    }
  }
}
