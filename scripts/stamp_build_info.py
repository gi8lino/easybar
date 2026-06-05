#!/usr/bin/env python3
"""Stamp the EasyBar build version into BuildInfo.swift."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


APP_VERSION_PATTERN = re.compile(r'public static let appVersion = ".*?"')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--file",
        default="Sources/EasyBarShared/Build/BuildInfo.swift",
        help="BuildInfo.swift file to update.",
    )
    parser.add_argument(
        "--version",
        required=True,
        help="Version string to write into BuildInfo.swift.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    path = Path(args.file)

    if not path.exists():
        print(f"Missing BuildInfo.swift file: {path}", file=sys.stderr)
        return 1

    text = path.read_text()
    replacement = f'public static let appVersion = "{args.version}"'
    updated, count = APP_VERSION_PATTERN.subn(replacement, text, count=1)

    if count != 1:
        print(
            f"Could not find appVersion declaration in {path}",
            file=sys.stderr,
        )
        return 1

    path.write_text(updated)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
