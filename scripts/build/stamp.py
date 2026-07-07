#!/usr/bin/env python3
"""Stamp EasyBar build metadata and bundle Info.plist files."""

from __future__ import annotations

import argparse
import plistlib
import re
import sys
from pathlib import Path


APP_VERSION_PATTERN = re.compile(r'public static let appVersion = ".*?"')
DEFAULT_BUILD_INFO = Path("Sources/EasyBarShared/Build/BuildInfo.swift")


def stamp_build_info(path: Path, version: str) -> int:
    if not path.exists():
        print(f"Missing BuildInfo.swift file: {path}", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    replacement = f'public static let appVersion = "{version}"'
    updated, count = APP_VERSION_PATTERN.subn(replacement, text, count=1)

    if count != 1:
        print(f"Could not find appVersion declaration in {path}", file=sys.stderr)
        return 1

    path.write_text(updated, encoding="utf-8")
    return 0


def stamp_plist(
    plist: Path,
    version: str,
    executable: str,
    name: str,
    icon_file: str,
    bundle_id: str | None,
) -> int:
    if not plist.exists():
        print(f"Missing Info.plist: {plist}", file=sys.stderr)
        return 1

    try:
        with plist.open("rb") as handle:
            values = plistlib.load(handle)
    except Exception as error:  # noqa: BLE001 - print a useful CLI error.
        print(f"Could not read Info.plist {plist}: {error}", file=sys.stderr)
        return 1

    if not isinstance(values, dict):
        print(f"Info.plist root is not a dictionary: {plist}", file=sys.stderr)
        return 1

    if bundle_id:
        values["CFBundleIdentifier"] = bundle_id

    values["CFBundleShortVersionString"] = version
    values["CFBundleVersion"] = version
    values["CFBundleExecutable"] = executable
    values["CFBundleName"] = name
    values["CFBundleDisplayName"] = name
    values["CFBundleIconFile"] = icon_file

    try:
        with plist.open("wb") as handle:
            plistlib.dump(values, handle, fmt=plistlib.FMT_XML, sort_keys=False)
    except Exception as error:  # noqa: BLE001 - print a useful CLI error.
        print(f"Could not write Info.plist {plist}: {error}", file=sys.stderr)
        return 1

    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    build_info = subparsers.add_parser("build-info", help="Stamp BuildInfo.swift.")
    build_info.add_argument("--file", type=Path, default=DEFAULT_BUILD_INFO)
    build_info.add_argument("--version", required=True)

    plist = subparsers.add_parser("plist", help="Stamp one Info.plist file.")
    plist.add_argument("--plist", type=Path, required=True)
    plist.add_argument("--bundle-id")
    plist.add_argument("--version", required=True)
    plist.add_argument("--executable", required=True)
    plist.add_argument("--name", required=True)
    plist.add_argument("--icon-file", required=True)

    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.command == "build-info":
        return stamp_build_info(args.file, args.version)

    if args.command == "plist":
        return stamp_plist(
            plist=args.plist,
            version=args.version,
            executable=args.executable,
            name=args.name,
            icon_file=args.icon_file,
            bundle_id=args.bundle_id,
        )

    raise AssertionError(f"unsupported command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
