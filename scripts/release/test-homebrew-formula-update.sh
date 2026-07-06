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
calendar_formula="${tap_dir}/Formula/easybar-calendar-agent.rb"
network_formula="${tap_dir}/Formula/easybar-network-agent.rb"

for file in "${easybar_formula}" "${calendar_formula}" "${network_formula}"; do
  test -s "${file}"
  assert_contains "${file}" "url \"https://github.com/gi8lino/easybar/releases/download/${tag}/EasyBar-${version}.zip\""
  assert_contains "${file}" "sha256 \"${sha}\""
  assert_contains "${file}" "version \"${version}\""
done

assert_contains "${easybar_formula}" 'class Easybar < Formula'
assert_contains "${easybar_formula}" 'depends_on "lua"'
assert_contains "${easybar_formula}" 'depends_on "easybar-calendar-agent"'
assert_contains "${easybar_formula}" 'depends_on "easybar-network-agent"'
assert_contains "${easybar_formula}" 'run [opt_libexec/"EasyBar.app/Contents/MacOS/EasyBar"]'

assert_contains "${calendar_formula}" 'class EasybarCalendarAgent < Formula'
assert_contains "${calendar_formula}" 'libexec.install "EasyBarCalendarAgent.app"'
assert_contains "${calendar_formula}" 'run [opt_libexec/"EasyBarCalendarAgent.app/Contents/MacOS/EasyBarCalendarAgent"]'

assert_contains "${network_formula}" 'class EasybarNetworkAgent < Formula'
assert_contains "${network_formula}" 'libexec.install "EasyBarNetworkAgent.app"'
assert_contains "${network_formula}" 'run [opt_libexec/"EasyBarNetworkAgent.app/Contents/MacOS/EasyBarNetworkAgent"]'

"${repo_root}/scripts/release/commit-homebrew-formulas.sh" \
  --tap-dir "${tap_dir}" \
  --version "${version}" \
  --dry-run >/dev/null

if git -C "${tap_dir}" diff --cached --quiet; then
  echo "Expected dry-run commit script to stage formula changes." >&2
  exit 1
fi
