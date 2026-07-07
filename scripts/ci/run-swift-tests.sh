#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 0 ]; then
  log_file="$1"
  shift
else
  log_file="test.log"
fi

if [ "$#" -gt 0 ]; then
  test_command=("$@")
else
  test_command=(make test)
fi

heartbeat_interval="${CI_HEARTBEAT_INTERVAL_SECONDS:-30}"
case "$heartbeat_interval" in
  ''|*[!0-9]*|0)
    echo "CI_HEARTBEAT_INTERVAL_SECONDS must be a positive integer, got: $heartbeat_interval" >&2
    exit 2
    ;;
esac

test_pid=""
heartbeat_pid=""

: >"${log_file}"

echo "Running: ${test_command[*]}" | tee -a "${log_file}"

process_running() {
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

terminate_process_tree() {
  local pid="$1"
  local signal="$2"
  local children=""
  local child=""

  children=$(pgrep -P "$pid" 2>/dev/null || true)
  for child in $children; do
    terminate_process_tree "$child" "$signal"
  done

  kill "-${signal}" "$pid" 2>/dev/null || true
}

stop_heartbeat() {
  if process_running "$heartbeat_pid"; then
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
  fi
}

cleanup() {
  local status=$?
  trap - INT TERM HUP EXIT

  stop_heartbeat

  if process_running "$test_pid"; then
    echo "Stopping test command..." | tee -a "${log_file}"
    terminate_process_tree "$test_pid" TERM
    sleep 2

    if process_running "$test_pid"; then
      echo "Force-stopping test command..." | tee -a "${log_file}"
      terminate_process_tree "$test_pid" KILL
    fi

    wait "$test_pid" 2>/dev/null || true
  fi

  exit "$status"
}

trap cleanup INT TERM HUP EXIT

"${test_command[@]}" >>"${log_file}" 2>&1 &
test_pid=$!

(
  while true; do
    sleep "$heartbeat_interval"

    if ! process_running "$test_pid"; then
      exit 0
    fi

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    {
      echo
      echo "---- ${test_command[*]} still running at ${timestamp}; last 80 lines ----"
      tail -n 80 "${log_file}" || true
      echo "---- end heartbeat ----"
      echo
    }

    {
      echo
      echo "---- ${test_command[*]} still running at ${timestamp}; see GitHub step log for last 80 lines ----"
      echo
    } >>"${log_file}"
  done
) &
heartbeat_pid=$!

set +e
wait "$test_pid"
status=$?
set -e

stop_heartbeat
trap - INT TERM HUP EXIT

if [ "$status" -ne 0 ]; then
  echo "---- extracted failures ----"
  grep -nE "(: error:|XCTAssert|failed -|Test Case '.*failed|Test Suite '.*failed)" "${log_file}" || true

  echo "---- full test log ----"
  cat "${log_file}"

  exit "$status"
fi

echo "Command finished successfully: ${test_command[*]}" | tee -a "${log_file}"
