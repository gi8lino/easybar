#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

tap_dir="${tmp_dir}/homebrew-tap"
version="9.8.7"
tag="v${version}"
sha="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

mkdir -p "${tap_dir}"
git -C "${tap_dir}" init -q
mkdir -p "${tap_dir}/Formula"
touch \
  "${tap_dir}/Formula/easybar-calendar-agent.rb" \
  "${tap_dir}/Formula/easybar-network-agent.rb"
git -C "${tap_dir}" add Formula
git -C "${tap_dir}" -c user.name=test -c user.email=test@example.com commit -qm fixture

"${repo_root}/scripts/release/update-homebrew-formulas.sh" \
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
    echo "--- ${file} ---" >&2
    cat "${file}" >&2
    exit 1
  fi
}

easybar_formula="${tap_dir}/Formula/easybar.rb"
test -s "${easybar_formula}"
assert_contains "${easybar_formula}" "url \"https://github.com/gi8lino/easybar/releases/download/${tag}/EasyBar-${version}.zip\""
assert_contains "${easybar_formula}" "sha256 \"${sha}\""
assert_contains "${easybar_formula}" "version \"${version}\""

assert_contains "${easybar_formula}" 'class Easybar < Formula'
assert_contains "${easybar_formula}" 'depends_on "lua"'
assert_contains "${easybar_formula}" 'run [opt_libexec/"EasyBar.app/Contents/MacOS/EasyBar"]'
assert_contains "${easybar_formula}" 'EasyBar.app/Contents/Library/LoginItems/EasyBarCalendarAgent.app'
assert_contains "${easybar_formula}" 'EasyBar.app/Contents/Library/LoginItems/EasyBarNetworkAgent.app'

test ! -e "${tap_dir}/Formula/easybar-calendar-agent.rb"
test ! -e "${tap_dir}/Formula/easybar-network-agent.rb"

"${repo_root}/scripts/release/commit-homebrew-formulas.sh" \
  --tap-dir "${tap_dir}" \
  --version "${version}" \
  --dry-run >/dev/null

if git -C "${tap_dir}" diff --cached --quiet; then
  echo "Expected dry-run commit script to stage formula changes." >&2
  exit 1
fi
