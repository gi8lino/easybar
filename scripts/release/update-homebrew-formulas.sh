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

cat > "${easybar_formula_file}" <<EOF_FORMULA
class Easybar < Formula
  desc "Scriptable macOS status bar with SwiftUI and Lua widgets"
  homepage "https://github.com/${repository}"
  url "${asset_url}"
  sha256 "${sha}"
  license "Apache-2.0"
  version "${version}"

  depends_on macos: :sonoma
  depends_on "easybar-calendar-agent"
  depends_on "easybar-network-agent"

  def install
    libexec.install "EasyBar.app"
    bin.install "easybar"

    (var/"log/easybar").mkpath
  end

  service do
    run [opt_libexec/"EasyBar.app/Contents/MacOS/EasyBar"]
    environment_variables PATH: std_service_path_env, LANG: "en_US.UTF-8"
    keep_alive true
    process_type :interactive
    working_dir HOMEBREW_PREFIX
    log_path var/"log/easybar/easybar.out.log"
    error_log_path var/"log/easybar/easybar.err.log"
  end

  test do
    assert_match "easybar", shell_output("#{bin}/easybar --help 2>&1")
  end
end
EOF_FORMULA

cat > "${calendar_agent_formula_file}" <<EOF_FORMULA
class EasybarCalendarAgent < Formula
  desc "Calendar EventKit helper service for EasyBar"
  homepage "https://github.com/${repository}"
  url "${asset_url}"
  sha256 "${sha}"
  license "Apache-2.0"
  version "${version}"

  depends_on macos: :sonoma

  def install
    libexec.install "EasyBarCalendarAgent.app"

    (var/"log/easybar-calendar-agent").mkpath
  end

  service do
    run [opt_libexec/"EasyBarCalendarAgent.app/Contents/MacOS/EasyBarCalendarAgent"]
    environment_variables PATH: std_service_path_env, LANG: "en_US.UTF-8"
    keep_alive true
    process_type :interactive
    working_dir HOMEBREW_PREFIX
    log_path var/"log/easybar-calendar-agent/easybar-calendar-agent.out.log"
    error_log_path var/"log/easybar-calendar-agent/easybar-calendar-agent.err.log"
  end

  test do
    assert_predicate libexec/"EasyBarCalendarAgent.app", :exist?
  end
end
EOF_FORMULA

cat > "${network_agent_formula_file}" <<EOF_FORMULA
class EasybarNetworkAgent < Formula
  desc "Wi-Fi and network helper service for EasyBar"
  homepage "https://github.com/${repository}"
  url "${asset_url}"
  sha256 "${sha}"
  license "Apache-2.0"
  version "${version}"

  depends_on macos: :sonoma

  def install
    libexec.install "EasyBarNetworkAgent.app"

    (var/"log/easybar-network-agent").mkpath
  end

  service do
    run [opt_libexec/"EasyBarNetworkAgent.app/Contents/MacOS/EasyBarNetworkAgent"]
    environment_variables PATH: std_service_path_env, LANG: "en_US.UTF-8"
    keep_alive true
    process_type :interactive
    working_dir HOMEBREW_PREFIX
    log_path var/"log/easybar-network-agent/easybar-network-agent.out.log"
    error_log_path var/"log/easybar-network-agent/easybar-network-agent.err.log"
  end

  test do
    assert_predicate libexec/"EasyBarNetworkAgent.app", :exist?
  end
end
EOF_FORMULA
