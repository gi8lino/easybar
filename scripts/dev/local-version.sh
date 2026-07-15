#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF_USAGE'
Usage: scripts/dev/local-version.sh [--version-prefix PREFIX]

Print the version used by make install-local. The version contains the latest
release version, the current short Git commit, and a -dirty suffix when the
working tree contains source changes.
EOF_USAGE
}

version_prefix="${VERSION_PREFIX:-v}"

while [ "$#" -gt 0 ]; do
  case "$1" in
  --version-prefix)
    if [ "$#" -lt 2 ]; then
      echo "Missing value for --version-prefix" >&2
      exit 2
    fi
    version_prefix="$2"
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

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "$script_dir/../.." && pwd -P)"
cd "$project_root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Local version requires a Git working tree: $project_root" >&2
  exit 1
fi

head_commit="$(git rev-parse --verify HEAD)"
short_commit="$(git rev-parse --short=8 "$head_commit")"
latest_tag="$(git tag --list "${version_prefix}*" --sort=-v:refname | head -n 1)"

if [ -n "$latest_tag" ]; then
  base_version="${latest_tag#"$version_prefix"}"
else
  base_version="0.0.0"
fi

build_info_path="Sources/EasyBarShared/Build/BuildInfo.swift"
lua_api_stub_path="Sources/EasyBarApp/Lua/easybar_api.lua"

dirty=false

# Compare all tracked files except the two files whose version strings are
# intentionally rewritten by prepare-version. They are normalized separately
# below so real edits to either file still make the build dirty.
if ! git diff --quiet HEAD -- . \
  ":(exclude)$build_info_path" \
  ":(exclude)$lua_api_stub_path"; then
  dirty=true
fi

if [ -n "$(git ls-files --others --exclude-standard)" ]; then
  dirty=true
fi

normalize_build_info() {
  sed -E 's/public static let appVersion = "[^"]*"/public static let appVersion = "__LOCAL_VERSION__"/'
}

normalize_lua_api_stub() {
  sed -E \
    -e 's/^-- EasyBar Lua API stub version: .*/-- EasyBar Lua API stub version: __LOCAL_VERSION__/' \
    -e 's/EasyBar application version \(`[^`]*`\)/EasyBar application version (`__LOCAL_VERSION__`)/g' \
    -e 's/^EasyBar\.version = "[^"]*"$/EasyBar.version = "__LOCAL_VERSION__"/'
}

if [ -f "$build_info_path" ]; then
  if ! cmp -s \
    <(git show "HEAD:$build_info_path" | normalize_build_info) \
    <(normalize_build_info <"$build_info_path"); then
    dirty=true
  fi
else
  dirty=true
fi

if [ -f "$lua_api_stub_path" ]; then
  if ! cmp -s \
    <(git show "HEAD:$lua_api_stub_path" | normalize_lua_api_stub) \
    <(normalize_lua_api_stub <"$lua_api_stub_path"); then
    dirty=true
  fi
else
  dirty=true
fi

version="${base_version}-dev.${short_commit}"
if [ "$dirty" = true ]; then
  version="${version}-dirty"
fi

printf '%s\n' "$version"
