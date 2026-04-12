import Darwin
import EasyBarShared
import Foundation

/// Samples lightweight process stats for EasyBar, Lua, and helper agents.
final class ProcessSampler {
  private struct CPUSample {
    let sampledAt: TimeInterval
    let totalCPUTime: UInt64
  }

  private var previousCPUSamples: [Int32: CPUSample] = [:]
  private let lock = NSLock()

  /// Samples the current EasyBar process.
  func sampleCurrentProcess(named name: String, now: Date) -> IPC.ProcessMetrics {
    sampleProcess(named: name, pid: Int32(ProcessInfo.processInfo.processIdentifier), now: now)
  }

  /// Samples one arbitrary process identifier when it is available.
  func sampleProcess(named name: String, pid: Int32?, now: Date) -> IPC.ProcessMetrics {
    guard let pid, pid > 0 else {
      return IPC.ProcessMetrics(name: name, running: false)
    }

    guard let info = readTaskInfo(for: pid) else {
      _ = withLock {
        previousCPUSamples.removeValue(forKey: pid)
      }
      return IPC.ProcessMetrics(name: name, running: false, pid: pid)
    }

    let cpuPercent = resolveCPUPercent(pid: pid, totalCPUTime: info.totalCPUTime, now: now)

    return IPC.ProcessMetrics(
      name: name,
      running: true,
      pid: pid,
      cpuPercent: cpuPercent,
      residentSizeBytes: info.residentSizeBytes,
      threadCount: info.threadCount
    )
  }

  /// Samples the first running process matching one executable name.
  func sampleProcessNamed(
    named name: String,
    executableName: String,
    now: Date
  ) -> IPC.ProcessMetrics {
    let pid = firstPID(named: executableName)
    return sampleProcess(named: name, pid: pid, now: now)
  }

  /// Clears cached CPU deltas for one process when it fully goes away.
  func clear(pid: Int32?) {
    guard let pid else { return }
    _ = withLock {
      previousCPUSamples.removeValue(forKey: pid)
    }
  }

  private func resolveCPUPercent(pid: Int32, totalCPUTime: UInt64, now: Date) -> Double? {
    withLock {
      let timestamp = now.timeIntervalSinceReferenceDate
      defer {
        previousCPUSamples[pid] = CPUSample(sampledAt: timestamp, totalCPUTime: totalCPUTime)
      }

      guard let previous = previousCPUSamples[pid] else {
        return nil
      }

      let wallDelta = timestamp - previous.sampledAt
      guard wallDelta > 0 else { return nil }

      let cpuDelta =
        totalCPUTime >= previous.totalCPUTime ? totalCPUTime - previous.totalCPUTime : 0
      let cpuSeconds = Double(cpuDelta) / 1_000_000_000
      return (cpuSeconds / wallDelta) * 100
    }
  }

  private func readTaskInfo(for pid: Int32) -> (
    residentSizeBytes: UInt64, threadCount: Int, totalCPUTime: UInt64
  )? {
    var taskInfo = proc_taskinfo()
    let expectedSize = Int32(MemoryLayout<proc_taskinfo>.stride)

    let result = proc_pidinfo(
      pid,
      PROC_PIDTASKINFO,
      0,
      &taskInfo,
      expectedSize
    )

    guard result == expectedSize else {
      return nil
    }

    let totalCPUTime = UInt64(taskInfo.pti_total_user) + UInt64(taskInfo.pti_total_system)
    return (
      residentSizeBytes: UInt64(taskInfo.pti_resident_size),
      threadCount: Int(taskInfo.pti_threadnum),
      totalCPUTime: totalCPUTime
    )
  }

  private func firstPID(named executableName: String) -> Int32? {
    let estimatedCount = Int(proc_listallpids(nil, 0))
    let capacity = max(estimatedCount + 32, 256)
    var pids = [Int32](repeating: 0, count: capacity)
    let bytes = Int32(pids.count * MemoryLayout<Int32>.stride)
    let filledBytes = proc_listallpids(&pids, bytes)

    guard filledBytes > 0 else { return nil }

    let filledCount = Int(filledBytes) / MemoryLayout<Int32>.stride

    for pid in pids.prefix(filledCount) where pid > 0 {
      var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
      let length = proc_name(pid, &buffer, UInt32(buffer.count))
      guard length > 0 else { continue }

      if String(cString: buffer) == executableName {
        return pid
      }
    }

    return nil
  }

  private func withLock<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }
}
