#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "package failed at line $LINENO: $BASH_COMMAND" >&2' ERR

usage() {
  cat >&2 <<'EOF_USAGE'
Usage: scripts/release/package.sh [--version <version>] [--dist-dir <dir>]

Options:
  --version <version>  Package version. Default: VERSION or dev
  --dist-dir <dir>    Distribution directory. Default: DIST_DIR or dist
EOF_USAGE
}

version="${VERSION:-dev}"
dist_dir="${DIST_DIR:-dist}"

while [ "$#" -gt 0 ]; do
  case "$1" in
  --version)
    version="${2:?missing value for --version}"
    shift 2
    ;;
  --dist-dir)
    dist_dir="${2:?missing value for --dist-dir}"
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

package_stage="$dist_dir/package"
package_zip="$dist_dir/EasyBar-$version.zip"
app_bundle="$dist_dir/EasyBar.app"
cli_bin="$dist_dir/easybar"

require_path() {
  local path="$1"
  local label="$2"

  if [ ! -e "$path" ]; then
    echo "Missing ${label}: ${path}" >&2
    exit 1
  fi
}

require_path "$app_bundle" "app bundle"
require_path "$cli_bin" "CLI binary"

package_dir=$(dirname "$package_zip")
package_name=$(basename "$package_zip")
mkdir -p "$package_dir"
package_zip="$(cd "$package_dir" && pwd)/${package_name}"

rm -rf "$package_stage" "$package_zip"
mkdir -p "$package_stage"

cp -R "$app_bundle" "$package_stage/EasyBar.app"
cp "$cli_bin" "$package_stage/easybar"

(
  cd "$package_stage"
  zip -qry "$package_zip" \
    "EasyBar.app" \
    "easybar"
)

rm -rf "$package_stage"
echo "Created $package_zip"
