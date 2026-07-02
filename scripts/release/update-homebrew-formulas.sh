#!/usr/bin/env bash
set -euo pipefail

tap_dir=""
repository="${GITHUB_REPOSITORY:-gi8lino/easybar}"
tag=""
version=""
sha=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tap-dir)
      tap_dir="${2:?missing value for --tap-dir}"
      shift 2
      ;;
    --repository)
      repository="${2:?missing value for --repository}"
      shift 2
      ;;
    --tag)
      tag="${2:?missing value for --tag}"
      shift 2
      ;;
    --version)
      version="${2:?missing value for --version}"
      shift 2
      ;;
    --sha)
      sha="${2:?missing value for --sha}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "${tap_dir}" ] || [ -z "${version}" ] || [ -z "${sha}" ]; then
  echo "Usage: $0 --tap-dir DIR --version VERSION --sha SHA [--repository OWNER/REPO] [--tag TAG]" >&2
  exit 2
fi

if [ -z "${tag}" ]; then
  tag="v${version}"
fi

formula_dir="${tap_dir}/Formula"
easybar_formula_file="${formula_dir}/easybar.rb"
calendar_agent_formula_file="${formula_dir}/easybar-calendar-agent.rb"
network_agent_formula_file="${formula_dir}/easybar-network-agent.rb"
asset_url="https://github.com/${repository}/releases/download/${tag}/EasyBar-${version}.zip"

mkdir -p "${formula_dir}"

write_formula_header() {
  local file="$1"
  local class_name="$2"
  local description="$3"

  cat > "$file" <<EOF_FORMULA
class ${class_name} < Formula
  desc "${description}"
  homepage "https://github.com/${repository}"
  url "${asset_url}"
  sha256 "${sha}"
  license "Apache-2.0"
  version "${version}"

  depends_on macos: :sonoma
EOF_FORMULA
}

append_service_block() {
  local file="$1"
  local executable="$2"
  local log_dir="$3"
  local log_name="$4"

  cat >> "$file" <<EOF_FORMULA

  service do
    run [opt_libexec/"${executable}"]
    environment_variables PATH: std_service_path_env, LANG: "en_US.UTF-8"
    keep_alive true
    process_type :interactive
    working_dir HOMEBREW_PREFIX
    log_path var/"log/${log_dir}/${log_name}.out.log"
    error_log_path var/"log/${log_dir}/${log_name}.err.log"
  end
EOF_FORMULA
}

append_formula_end() {
  local file="$1"

  cat >> "$file" <<'EOF_FORMULA'
end
EOF_FORMULA
}

write_easybar_formula() {
  write_formula_header \
    "${easybar_formula_file}" \
    "Easybar" \
    "Scriptable macOS status bar with SwiftUI and Lua widgets"

  cat >> "${easybar_formula_file}" <<'EOF_FORMULA'
  depends_on "lua"
  depends_on "easybar-calendar-agent"
  depends_on "easybar-network-agent"

  def install
    libexec.install "EasyBar.app"
    bin.install "easybar"

    (var/"log/easybar").mkpath
  end
EOF_FORMULA

  append_service_block \
    "${easybar_formula_file}" \
    "EasyBar.app/Contents/MacOS/EasyBar" \
    "easybar" \
    "easybar"

  cat >> "${easybar_formula_file}" <<'EOF_FORMULA'

  test do
    assert_match "easybar", shell_output("#{bin}/easybar --help 2>&1")
  end
EOF_FORMULA

  append_formula_end "${easybar_formula_file}"
}

write_agent_formula() {
  local file="$1"
  local class_name="$2"
  local description="$3"
  local app_name="$4"
  local log_dir="$5"
  local log_name="$6"

  write_formula_header "$file" "$class_name" "$description"

  cat >> "$file" <<EOF_FORMULA

  def install
    libexec.install "${app_name}.app"

    (var/"log/${log_dir}").mkpath
  end
EOF_FORMULA

  append_service_block \
    "$file" \
    "${app_name}.app/Contents/MacOS/${app_name}" \
    "$log_dir" \
    "$log_name"

  cat >> "$file" <<EOF_FORMULA

  test do
    assert_predicate libexec/"${app_name}.app", :exist?
  end
EOF_FORMULA

  append_formula_end "$file"
}

write_easybar_formula
write_agent_formula \
  "${calendar_agent_formula_file}" \
  "EasybarCalendarAgent" \
  "Calendar EventKit helper service for EasyBar" \
  "EasyBarCalendarAgent" \
  "easybar-calendar-agent" \
  "easybar-calendar-agent"
write_agent_formula \
  "${network_agent_formula_file}" \
  "EasybarNetworkAgent" \
  "Wi-Fi and network helper service for EasyBar" \
  "EasyBarNetworkAgent" \
  "easybar-network-agent" \
  "easybar-network-agent"


