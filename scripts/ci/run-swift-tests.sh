#!/usr/bin/env bash
set -euo pipefail

log_file="${1:-test.log}"
shift || true

if [ "$#" -gt 0 ]; then
  test_command=("$@")
else
  test_command=(make test)
fi

"${test_command[@]}" > "${log_file}" 2>&1 &
test_pid=$!

while kill -0 "${test_pid}" 2>/dev/null; do
  sleep 30
  echo "---- ${test_command[*]} still running; last 80 lines ----"
  tail -n 80 "${log_file}" || true
done

set +e
wait "${test_pid}"
status=$?
set -e

if [ "${status}" -ne 0 ]; then
  echo "---- extracted failures ----"
  grep -nE "(: error:|XCTAssert|failed -|Test Case '.*failed|Test Suite '.*failed)" "${log_file}" || true
  echo "---- full test log ----"
  cat "${log_file}"
  exit "${status}"
fi
