#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat >&2 <<'EOF_USAGE'
Usage: scripts/dev/uninstall-local.sh [options]

Remove the standalone local EasyBar installation created by make install-local.
If released Homebrew agent formulae are installed, their services are started
again after the local LaunchAgents are removed.

Options:
  --app-dir <dir>           App installation directory. Default: ~/Applications
  --bin-dir <dir>           CLI installation directory. Default: ~/.local/bin
  --agent-dir <dir>         Helper-agent directory. Default: ~/Library/Application Support/EasyBar/Agents
  --launch-agent-dir <dir>  LaunchAgent plist directory. Default: ~/Library/LaunchAgents
EOF_USAGE
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/../.." && pwd -P)"

app_dir="${LOCAL_APP_DIR:-$HOME/Applications}"
bin_dir="${LOCAL_BIN_DIR:-$HOME/.local/bin}"
agent_dir="${LOCAL_AGENT_DIR:-$HOME/Library/Application Support/EasyBar/Agents}"
launch_agent_dir="${LOCAL_LAUNCH_AGENT_DIR:-$HOME/Library/LaunchAgents}"

while [ "$#" -gt 0 ]; do
  case "$1" in
  --app-dir)
    app_dir="${2:?missing value for --app-dir}"
    shift 2
    ;;
  --bin-dir)
    bin_dir="${2:?missing value for --bin-dir}"
    shift 2
    ;;
  --agent-dir)
    agent_dir="${2:?missing value for --agent-dir}"
    shift 2
    ;;
  --launch-agent-dir)
    launch_agent_dir="${2:?missing value for --launch-agent-dir}"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $1" >&2
    usage
    exit 2
    ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Local uninstallation is supported only on macOS." >&2
  exit 1
fi

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
}

remove_path() {
  local path="$1"
  local parent

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return
  fi

  parent="$(dirname -- "$path")"
  if [ -w "$parent" ]; then
    rm -rf "$path"
    return
  fi

  require_command sudo
  sudo rm -rf "$path"
}

start_homebrew_service_if_installed() {
  local formula="$1"

  if [ -z "$brew_command" ]; then
    return
  fi
  if ! "$brew_command" list --formula "$formula" >/dev/null 2>&1; then
    return
  fi

  echo "Starting released Homebrew service: $formula"
  "$brew_command" services start "$formula" >/dev/null
}

require_command launchctl

calendar_label="io.github.gi8lino.easybar.local.calendar-agent"
network_label="io.github.gi8lino.easybar.local.network-agent"
user_domain="gui/$(id -u)"

app_destination="${app_dir%/}/EasyBar.app"
calendar_agent_destination="${agent_dir%/}/EasyBarCalendarAgent.app"
network_agent_destination="${agent_dir%/}/EasyBarNetworkAgent.app"
cli_destination="${bin_dir%/}/easybar"
calendar_plist="${launch_agent_dir%/}/${calendar_label}.plist"
network_plist="${launch_agent_dir%/}/${network_label}.plist"

launchctl bootout "$user_domain/$calendar_label" >/dev/null 2>&1 || true
launchctl bootout "$user_domain/$network_label" >/dev/null 2>&1 || true
bash "$project_root/scripts/dev/stop-local.sh" --dist-dir "$project_root/dist"

remove_path "$calendar_plist"
remove_path "$network_plist"
remove_path "$app_destination"
remove_path "$calendar_agent_destination"
remove_path "$network_agent_destination"
remove_path "$cli_destination"

brew_command="$(command -v brew || true)"
start_homebrew_service_if_installed easybar-calendar-agent
start_homebrew_service_if_installed easybar-network-agent

cat <<EOF_SUMMARY
Local EasyBar installation removed.

Removed app:            $app_destination
Removed CLI:            $cli_destination
Removed calendar agent: $calendar_agent_destination
Removed network agent:  $network_agent_destination
EOF_SUMMARY
