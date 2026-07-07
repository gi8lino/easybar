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
timeout_minutes="${CI_COMMAND_TIMEOUT_MINUTES:-0}"
test_pid=""
heartbeat_pid=""

case "${heartbeat_interval}" in
'' | *[!0-9]*)
  echo "CI_HEARTBEAT_INTERVAL_SECONDS must be a positive integer" >&2
  exit 2
  ;;
esac

if [ "${heartbeat_interval}" -le 0 ]; then
  echo "CI_HEARTBEAT_INTERVAL_SECONDS must be greater than zero" >&2
  exit 2
fi

case "${timeout_minutes}" in
'' | *[!0-9]*)
  echo "CI_COMMAND_TIMEOUT_MINUTES must be a non-negative integer" >&2
  exit 2
  ;;
esac

timeout_seconds=0
if [ "${timeout_minutes}" -gt 0 ]; then
  timeout_seconds=$((timeout_minutes * 60))
fi

: >"${log_file}"

echo "Running: ${test_command[*]}" | tee -a "${log_file}"
if [ "${timeout_seconds}" -gt 0 ]; then
  echo "Command timeout: ${timeout_minutes} minute(s)" | tee -a "${log_file}"
else
  echo "Command timeout: disabled" | tee -a "${log_file}"
fi

cleanup() {
  local status=$?
  trap - INT TERM HUP EXIT

  if [ -n "${heartbeat_pid}" ]; then
    kill "${heartbeat_pid}" 2>/dev/null || true
    wait "${heartbeat_pid}" 2>/dev/null || true
  fi

  if [ -n "${test_pid}" ] && kill -0 "${test_pid}" 2>/dev/null; then
    echo "Stopping test command..." | tee -a "${log_file}"
    kill "${test_pid}" 2>/dev/null || true
    sleep 2
    kill -9 "${test_pid}" 2>/dev/null || true
    wait "${test_pid}" 2>/dev/null || true
  fi

  exit "${status}"
}

trap cleanup INT TERM HUP EXIT

start_epoch="$(date +%s)"

"${test_command[@]}" >>"${log_file}" 2>&1 &
test_pid=$!

(
  while true; do
    sleep "${heartbeat_interval}"

    if ! kill -0 "${test_pid}" 2>/dev/null; then
      exit 0
    fi

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    now_epoch="$(date +%s)"
    elapsed_seconds=$((now_epoch - start_epoch))

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

    if [ "${timeout_seconds}" -gt 0 ] && [ "${elapsed_seconds}" -ge "${timeout_seconds}" ]; then
      {
        echo
        echo "Command timed out after ${timeout_minutes} minute(s): ${test_command[*]}"
        echo
      } | tee -a "${log_file}"

      kill "${test_pid}" 2>/dev/null || true
      sleep 2
      kill -9 "${test_pid}" 2>/dev/null || true
      exit 0
    fi
  done
) &
heartbeat_pid=$!

set +e
wait "${test_pid}"
status=$?
set -e

kill "${heartbeat_pid}" 2>/dev/null || true
wait "${heartbeat_pid}" 2>/dev/null || true

trap - INT TERM HUP EXIT

if [ "${status}" -ne 0 ]; then
  echo "---- extracted failures ----"
  grep -nE "(: error:|XCTAssert|failed -|Test Case '.*failed|Test Suite '.*failed|Command timed out)" "${log_file}" || true

  echo "---- full test log ----"
  cat "${log_file}"

  exit "${status}"
fi

echo "Command finished successfully: ${test_command[*]}" | tee -a "${log_file}"
