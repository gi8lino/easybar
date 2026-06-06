#!/usr/bin/env bash
set -euo pipefail

plist=""
bundle_id=""
version=""
executable=""
name=""
icon_file=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --plist)
      plist="$2"
      shift 2
      ;;
    --bundle-id)
      bundle_id="$2"
      shift 2
      ;;
    --version)
      version="$2"
      shift 2
      ;;
    --executable)
      executable="$2"
      shift 2
      ;;
    --name)
      name="$2"
      shift 2
      ;;
    --icon-file)
      icon_file="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [ -z "$plist" ] || [ -z "$version" ] || [ -z "$executable" ] || [ -z "$name" ] || [ -z "$icon_file" ]; then
  echo "Usage: $0 --plist <path> [--bundle-id <id>] --version <version> --executable <name> --name <name> --icon-file <name>" >&2
  exit 2
fi

if [ -n "$bundle_id" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$plist"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $version" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $executable" "$plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $name" "$plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $name" "$plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $icon_file" "$plist" >/dev/null 2>&1 || \
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile $icon_file" "$plist"
