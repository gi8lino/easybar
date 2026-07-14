#!/usr/bin/env bash
set -euo pipefail

tap_dir=""
repository="${GITHUB_REPOSITORY:-gi8lino/easybar}"
tag=""
version=""
sha=""

while [ "$#" -gt 0 ]; do
  case "$1" in
  --tap-dir) tap_dir="${2:?missing value for --tap-dir}"; shift 2 ;;
  --repository) repository="${2:?missing value for --repository}"; shift 2 ;;
  --tag) tag="${2:?missing value for --tag}"; shift 2 ;;
  --version) version="${2:?missing value for --version}"; shift 2 ;;
  --sha) sha="${2:?missing value for --sha}"; shift 2 ;;
  *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "${tap_dir}" ] || [ -z "${version}" ] || [ -z "${sha}" ]; then
  echo "Usage: $0 --tap-dir DIR --version VERSION --sha SHA [--repository OWNER/REPO] [--tag TAG]" >&2
  exit 2
fi

if [ -z "${tag}" ]; then
  tag="v${version}"
fi

cask_dir="${tap_dir}/Casks"
easybar_cask_file="${cask_dir}/easybar.rb"
asset_url="https://github.com/${repository}/releases/download/${tag}/EasyBar-${version}.zip"

mkdir -p "${cask_dir}"

cat >"${easybar_cask_file}" <<EOF_CASK
cask "easybar" do
  version "${version}"
  sha256 "${sha}"

  url "${asset_url}"
  name "EasyBar"
  desc "Scriptable macOS status bar with SwiftUI and Lua widgets"
  homepage "https://github.com/${repository}"

  depends_on macos: :sonoma

  postflight do
    system "xattr -d com.apple.quarantine #{staged_path}/easybar"
    system "xattr -dr com.apple.quarantine #{appdir}/EasyBar.app"
  end

  app "EasyBar.app"
  binary "easybar"

  zap trash: [
    "~/.config/easybar",
    "~/.local/state/easybar",
  ]
end
EOF_CASK

# Remove formulas made obsolete by the self-contained EasyBar cask.
rm -f \
  "${tap_dir}/Formula/easybar.rb" \
  "${tap_dir}/Formula/easybar-calendar-agent.rb" \
  "${tap_dir}/Formula/easybar-network-agent.rb"
