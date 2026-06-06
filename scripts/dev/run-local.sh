#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 11 ]; then
  echo "Usage: $0 <info|debug|trace> <run-arch> <version> <bundle-id> <app-macos-dir> <calendar-macos-dir> <network-macos-dir> <dist-dir> <calendar-agent-bin> <network-agent-bin> <app-bin>" >&2
  exit 2
fi

log_level="$1"
run_arch="$2"
version="$3"
bundle_id="$4"
app_macos="$5"
calendar_macos="$6"
network_macos="$7"
dist_dir="$8"
calendar_agent_bin="$9"
network_agent_bin="${10}"
app_bin="${11}"

case "$log_level" in
  info|debug|trace) ;;
  *)
    echo "Unsupported log level '$log_level'. Use info, debug, or trace." >&2
    exit 2
    ;;
esac

mkdir -p "$app_macos" "$calendar_macos" "$network_macos" "$dist_dir"

make --no-print-directory run-build-app RUN_ARCH="$run_arch"
make --no-print-directory run-build-lua-runtime RUN_ARCH="$run_arch"
make --no-print-directory run-build-calendar-agent RUN_ARCH="$run_arch"
make --no-print-directory run-build-network-agent RUN_ARCH="$run_arch"
make --no-print-directory run-build-cli RUN_ARCH="$run_arch"

echo "Copying debug resources"
make --no-print-directory copy-debug-resources RUN_ARCH="$run_arch"

echo "Preparing debug app bundle"
make --no-print-directory prepare-debug-app-bundle VERSION="$version" BUNDLE_ID="$bundle_id"

echo "Starting local helper agents"
nohup env EASYBAR_LOG_LEVEL="$log_level" "$calendar_agent_bin" >/tmp/easybar-calendar-agent.dev.log 2>&1 &
nohup env EASYBAR_LOG_LEVEL="$log_level" "$network_agent_bin" >/tmp/easybar-network-agent.dev.log 2>&1 &

echo "Launching $app_bin with EASYBAR_LOG_LEVEL=$log_level"
echo "App logs follow stdout/stderr and configured logging.directory"
env EASYBAR_LOG_LEVEL="$log_level" "$app_bin"
