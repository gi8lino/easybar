import Darwin
import EasyBarShared
import Foundation

/// Prints retained EasyBar logs and follows new records until interrupted.
func showLogs(options: LogCommandOptions, context: AppContext) throws {
  let runtimeConfig: SharedRuntimeConfig
  do {
    runtimeConfig = try SharedRuntimeConfig.load()
  } catch {
    throw AppError.message(
      "failed to resolve logging configuration: \(error.localizedDescription)"
    )
  }

  let directory = runtimeConfig.logging.directory
  guard ProcessLogStore.hasLogs(in: directory) else {
    throw AppError.message(
      "no EasyBar process logs found in \(directory); enable [logging].enabled and start EasyBar"
    )
  }

  let since: Date?
  if let value = options.since {
    guard let parsed = ProcessLogSinceParser.parse(value) else {
      throw AppError.message(
        "--since expects a duration such as 30m or an ISO-8601 timestamp"
      )
    }
    since = parsed
  } else {
    since = nil
  }

  let filter = ProcessLogFilter(
    widget: options.widget,
    runtime: options.runtime,
    minimumLevel: options.minimumLevel,
    requestID: options.requestID,
    since: since
  )
  let follower = ProcessLogFollower(directory: directory, filter: filter)
  let history = try ProcessLogStore.history(
    in: directory,
    filter: filter,
    limit: options.historyLimit
  )

  context.debug("reading EasyBar logs from \(directory)")
  printLogRecords(history, json: options.json)

  guard options.follow else { return }
  if !runtimeConfig.logging.enabled {
    CLIOutput.printWarning(
      "file logging is currently disabled; retained history is visible but new entries may not arrive"
    )
  }

  while true {
    usleep(250_000)
    printLogRecords(follower.poll(), json: options.json)
  }
}

/// Prints records in plain structured-text or JSON Lines format.
private func printLogRecords(_ records: [ProcessLogRecord], json: Bool) {
  for record in records {
    let line = json ? jsonLogLine(record) : "[\(record.source)] \(record.rawLine)"
    fputs(line + "\n", stdout)
  }
  if !records.isEmpty {
    fflush(stdout)
  }
}

/// Encodes one parsed record as a stable JSON object.
private func jsonLogLine(_ record: ProcessLogRecord) -> String {
  var object: [String: Any] = [
    "source": record.source,
    "message": record.message,
    "fields": record.fields,
  ]
  if let timestamp = record.timestampText {
    object["timestamp"] = timestamp
  }
  if let level = record.level {
    object["level"] = level.rawValue
  }
  if let runtime = record.runtime {
    object["runtime"] = runtime.rawValue
  }
  if let widget = record.widget {
    object["widget"] = widget
  }

  guard
    let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
    let text = String(data: data, encoding: .utf8)
  else { return #"{"message":"failed to encode log record"}"# }
  return text
}
