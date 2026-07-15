#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat >&2 <<'EOF_USAGE'
Usage: scripts/dev/install-local.sh [options]

Install the bundles from dist/ over an existing Homebrew EasyBar installation.

Options:
  --dist-dir <dir>  Distribution directory. Default: dist
  --app-dir <dir>   Directory containing EasyBar.app. Default: /Applications
  --no-launch       Install and restart agents without launching EasyBar.
EOF_USAGE
}

dist_dir="${DIST_DIR:-dist}"
app_dir="${LOCAL_APP_DIR:-/Applications}"
launch_app=true

while [ "$#" -gt 0 ]; do
  case "$1" in
  --dist-dir)
    dist_dir="${2:?missing value for --dist-dir}"
    shift 2
    ;;
  --app-dir)
    app_dir="${2:?missing value for --app-dir}"
    shift 2
    ;;
  --no-launch)
    launch_app=false
    shift
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
  echo "Local installation is supported only on macOS." >&2
  exit 1
fi

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
}

require_path() {
  local path="$1"
  local label="$2"

  if [ ! -e "$path" ]; then
    echo "Missing ${label}: ${path}" >&2
    exit 1
  fi
}

require_homebrew_install() {
  local kind="$1"
  local name="$2"

  if ! brew list "$kind" "$name" >/dev/null 2>&1; then
    echo "Homebrew package '${name}' is not installed." >&2
    echo "Install the released EasyBar cask once before using make install-local." >&2
    exit 1
  fi
}

ensure_directory() {
  local directory="$1"
  local parent

  if [ -d "$directory" ]; then
    return
  fi

  parent="$(dirname "$directory")"
  if [ -w "$parent" ]; then
    mkdir -p "$directory"
    return
  fi

  require_command sudo
  sudo mkdir -p "$directory"
}

replace_bundle() {
  local source="$1"
  local destination="$2"
  local parent
  local stage

  parent="$(dirname "$destination")"
  ensure_directory "$parent"
  stage="${parent}/.${destination##*/}.local-install.$$"

  if [ -w "$parent" ]; then
    rm -rf "$stage"
    ditto "$source" "$stage"
    rm -rf "$destination"
    mv "$stage" "$destination"
    return
  fi

  require_command sudo
  sudo rm -rf "$stage"
  sudo ditto "$source" "$stage"
  sudo rm -rf "$destination"
  sudo mv "$stage" "$destination"
}

replace_binary() {
  local source="$1"
  local destination="$2"
  local parent
  local stage="${destination}.local-install.$$"

  parent="$(dirname "$destination")"
  if [ -w "$parent" ]; then
    cp "$source" "$stage"
    chmod 0755 "$stage"
    mv -f "$stage" "$destination"
    return
  fi

  require_command sudo
  sudo cp "$source" "$stage"
  sudo chmod 0755 "$stage"
  sudo mv -f "$stage" "$destination"
}

require_command brew
require_command ditto
require_command open
require_command python3
require_command xattr

app_source="${dist_dir}/EasyBar.app"
calendar_agent_source="${dist_dir}/EasyBarCalendarAgent.app"
network_agent_source="${dist_dir}/EasyBarNetworkAgent.app"
cli_source="${dist_dir}/easybar"

require_path "$app_source" "EasyBar app bundle"
require_path "$calendar_agent_source" "calendar agent bundle"
require_path "$network_agent_source" "network agent bundle"
require_path "$cli_source" "EasyBar CLI"

require_homebrew_install --cask easybar
require_homebrew_install --formula easybar-calendar-agent
require_homebrew_install --formula easybar-network-agent

brew_prefix="$(brew --prefix)"
calendar_prefix="$(brew --prefix easybar-calendar-agent)"
network_prefix="$(brew --prefix easybar-network-agent)"

app_destination="${app_dir%/}/EasyBar.app"
calendar_agent_destination="${calendar_prefix}/libexec/EasyBarCalendarAgent.app"
network_agent_destination="${network_prefix}/libexec/EasyBarNetworkAgent.app"
cli_link="${brew_prefix}/bin/easybar"

require_path "$cli_link" "Homebrew EasyBar CLI link"
cli_destination="$(python3 - "$cli_link" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
)"
require_path "$cli_destination" "Homebrew EasyBar CLI target"

calendar_formula="easybar-calendar-agent"
network_formula="easybar-network-agent"
restart_services_on_exit=false

cleanup() {
  local status=$?
  trap - EXIT

  if [ "$restart_services_on_exit" = true ]; then
    echo "Restarting EasyBar agent services after interrupted installation" >&2
    brew services start "$calendar_formula" >/dev/null 2>&1 || true
    brew services start "$network_formula" >/dev/null 2>&1 || true
  fi

  exit "$status"
}
trap cleanup EXIT

echo "Stopping installed EasyBar and Homebrew agent services"
brew services stop "$calendar_formula" >/dev/null 2>&1 || true
brew services stop "$network_formula" >/dev/null 2>&1 || true
restart_services_on_exit=true
scripts/dev/stop-local.sh --dist-dir "$dist_dir"

echo "Installing EasyBar.app into $app_destination"
replace_bundle "$app_source" "$app_destination"

echo "Installing calendar agent into $calendar_agent_destination"
replace_bundle "$calendar_agent_source" "$calendar_agent_destination"

echo "Installing network agent into $network_agent_destination"
replace_bundle "$network_agent_source" "$network_agent_destination"

echo "Installing CLI into $cli_destination"
replace_binary "$cli_source" "$cli_destination"

xattr -dr com.apple.quarantine "$app_destination" >/dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$calendar_agent_destination" >/dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$network_agent_destination" >/dev/null 2>&1 || true
xattr -d com.apple.quarantine "$cli_destination" >/dev/null 2>&1 || true

echo "Starting Homebrew agent services"
brew services start "$calendar_formula"
brew services start "$network_formula"
restart_services_on_exit=false

installed_app_version="$($app_destination/Contents/MacOS/EasyBar --version)"
installed_cli_version="$($cli_destination --version)"
echo "Installed $installed_app_version"
echo "Installed $installed_cli_version"

if [ "$launch_app" = true ]; then
  echo "Launching $app_destination"
  open "$app_destination"
fi

cat <<EOF_SUMMARY

Local EasyBar build installed successfully.
Repeat 'make install-local' after further changes.
Restore the released packages with:
  brew reinstall gi8lino/tap/easybar-calendar-agent gi8lino/tap/easybar-network-agent
  brew reinstall --cask gi8lino/tap/easybar
EOF_SUMMARY
