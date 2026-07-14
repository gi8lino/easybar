#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF_USAGE'
Usage: scripts/dev/run-local.sh <info|debug|trace> [options]

Options:
  --run-arch <arm64|x86_64|universal>   Build/run architecture. Default: arm64
  --version <version>                   Version stamped into the debug app. Default: dev
  --bundle-id <id>                      App bundle identifier. Default: com.gi8lino.EasyBar
  --dist-dir <dir>                      Distribution directory. Default: dist
EOF_USAGE
}

if [ "$#" -lt 1 ]; then
  usage
  exit 2
fi

log_level="$1"
shift
run_arch="${RUN_ARCH:-arm64}"
version="${VERSION:-dev}"
bundle_id="${BUNDLE_ID:-com.gi8lino.EasyBar}"
dist_dir="${DIST_DIR:-dist}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-arch)
      run_arch="${2:?missing value for --run-arch}"
      shift 2
      ;;
    --version)
      version="${2:?missing value for --version}"
      shift 2
      ;;
    --bundle-id)
      bundle_id="${2:?missing value for --bundle-id}"
      shift 2
      ;;
    --dist-dir)
      dist_dir="${2:?missing value for --dist-dir}"
      shift 2
      ;;
    -h|--help)
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

case "$log_level" in
  info|debug|trace) ;;
  *)
    echo "Unsupported log level '$log_level'. Use info, debug, or trace." >&2
    exit 2
    ;;
esac

case "$run_arch" in
  arm64|x86_64|universal) ;;
  *)
    echo "Unsupported run architecture '$run_arch'. Use arm64, x86_64, or universal." >&2
    exit 2
    ;;
esac

app_name="EasyBar"
lua_runtime_product="EasyBarLuaRuntime"
calendar_agent_name="EasyBarCalendarAgent"
network_agent_name="EasyBarNetworkAgent"
cli_product="EasyBarCtl"
cli_exec="easybar"
resource_bundle_name="EasyBar_EasyBarApp.bundle"
themes_dir="themes"

app_bundle="$dist_dir/${app_name}.app"
app_contents="$app_bundle/Contents"
app_macos="$app_contents/MacOS"
app_resources="$app_contents/Resources"
app_resource_dir="$app_resources/$app_name"
app_themes_dir="$app_resources/Themes"
app_bin="$app_macos/$app_name"
lua_runtime_bin="$app_macos/$lua_runtime_product"
app_plist="$app_contents/Info.plist"

login_items="$app_contents/Library/LoginItems"
calendar_agent_bundle="$login_items/${calendar_agent_name}.app"
calendar_agent_macos="$calendar_agent_bundle/Contents/MacOS"
calendar_agent_bin="$calendar_agent_macos/$calendar_agent_name"
calendar_agent_plist="$calendar_agent_bundle/Contents/Info.plist"

network_agent_bundle="$login_items/${network_agent_name}.app"
network_agent_macos="$network_agent_bundle/Contents/MacOS"
network_agent_bin="$network_agent_macos/$network_agent_name"
network_agent_plist="$network_agent_bundle/Contents/Info.plist"

cli_bin="$dist_dir/$cli_exec"

mkdir -p "$app_macos" "$app_resources" "$calendar_agent_macos" "$network_agent_macos" "$dist_dir"

scripts/build/build-products.sh debug "$run_arch" \
  "$app_name=$app_bin" \
  "$lua_runtime_product=$lua_runtime_bin" \
  "$calendar_agent_name=$calendar_agent_bin" \
  "$network_agent_name=$network_agent_bin" \
  "$cli_product=$cli_bin"

echo "Copying debug resources"
scripts/build/copy-resources.sh \
  debug \
  "$run_arch" \
  "$resource_bundle_name" \
  "$app_bundle" \
  "$app_resource_dir" \
  "$themes_dir" \
  "$app_themes_dir"

echo "Preparing debug app bundle"
mkdir -p "$app_contents"
cp Sources/EasyBarApp/Info.plist "$app_plist"
cp Sources/EasyBarCalendarAgent/Info.plist "$calendar_agent_plist"
cp Sources/EasyBarNetworkAgent/Info.plist "$network_agent_plist"
scripts/build/stamp.py plist \
  --plist "$app_plist" \
  --bundle-id "$bundle_id" \
  --version "$version" \
  --executable "$app_name" \
  --name "$app_name" \
  --icon-file "$app_name"
touch "$app_bundle"

echo "Stopping existing EasyBar services and local processes"
scripts/dev/stop-local.sh --dist-dir "$dist_dir"

echo "Launching $app_bin with EASYBAR_LOG_LEVEL=$log_level"
echo "App logs follow stdout/stderr and configured logging.directory"
env EASYBAR_LOG_LEVEL="$log_level" "$app_bin"
