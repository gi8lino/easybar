#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

tap_dir="${tmp_dir}/homebrew-tap"
version="9.8.7"
tag="v${version}"
sha="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

mkdir -p "${tap_dir}/Formula"
git -C "${tap_dir}" init -q
touch "${tap_dir}/Formula/easybar.rb" \
  "${tap_dir}/Formula/easybar-calendar-agent.rb" \
  "${tap_dir}/Formula/easybar-network-agent.rb"
git -C "${tap_dir}" add Formula
git -C "${tap_dir}" -c user.name=test -c user.email=test@example.com commit -qm fixture

"${repo_root}/scripts/release/update-homebrew-cask.sh" \
  --tap-dir "${tap_dir}" \
  --repository gi8lino/easybar \
  --tag "${tag}" \
  --version "${version}" \
  --sha "${sha}"

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq "${expected}" "${file}"; then
    echo "Expected ${file} to contain: ${expected}" >&2
    cat "${file}" >&2
    exit 1
  fi
}

easybar_cask="${tap_dir}/Casks/easybar.rb"
test -s "${easybar_cask}"
assert_contains "${easybar_cask}" 'cask "easybar" do'
assert_contains "${easybar_cask}" "url \"https://github.com/gi8lino/easybar/releases/download/${tag}/EasyBar-${version}.zip\""
assert_contains "${easybar_cask}" "sha256 \"${sha}\""
assert_contains "${easybar_cask}" "version \"${version}\""
assert_contains "${easybar_cask}" 'depends_on macos: :sonoma'
assert_contains "${easybar_cask}" 'system "xattr -d com.apple.quarantine #{staged_path}/easybar"'
assert_contains "${easybar_cask}" 'system "xattr -dr com.apple.quarantine #{appdir}/EasyBar.app"'
assert_contains "${easybar_cask}" 'app "EasyBar.app"'
assert_contains "${easybar_cask}" 'binary "easybar"'

test ! -e "${tap_dir}/Formula/easybar.rb"
test ! -e "${tap_dir}/Formula/easybar-calendar-agent.rb"
test ! -e "${tap_dir}/Formula/easybar-network-agent.rb"

"${repo_root}/scripts/release/commit-homebrew-cask.sh" \
  --tap-dir "${tap_dir}" \
  --version "${version}" \
  --dry-run >/dev/null

if git -C "${tap_dir}" diff --cached --quiet; then
  echo "Expected dry-run commit script to stage cask changes." >&2
  exit 1
fi

# The commit helper must also work on subsequent releases after the old formulas are gone.
git -C "${tap_dir}" -c user.name=test -c user.email=test@example.com commit -qm "migrate to cask"
"${repo_root}/scripts/release/update-homebrew-cask.sh" \
  --tap-dir "${tap_dir}" \
  --repository gi8lino/easybar \
  --tag "v9.8.8" \
  --version "9.8.8" \
  --sha "${sha}"
"${repo_root}/scripts/release/commit-homebrew-cask.sh" \
  --tap-dir "${tap_dir}" \
  --version "9.8.8" \
  --dry-run >/dev/null
