#!/usr/bin/env python3
"""Regenerate checked-in documentation derived from source stubs."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

GENERATORS = [
    ROOT / "scripts/generate_lua_reference_docs.py",
]

STALE_DOC_PATTERNS = [
    "Sources/EasyBar/Lua/",
]

DOC_PATHS_TO_CHECK = [
    ROOT / "docs/content",
    ROOT / "README.md",
]


def run_generator(path: Path) -> None:
    if not path.exists():
        raise FileNotFoundError(f"missing generator: {path.relative_to(ROOT)}")

    subprocess.run([sys.executable, str(path)], cwd=ROOT, check=True)


def validate_no_stale_paths() -> None:
    offenders: list[str] = []

    for base in DOC_PATHS_TO_CHECK:
        paths = [base] if base.is_file() else base.rglob("*.md")
        for path in paths:
            text = path.read_text(encoding="utf-8")
            for pattern in STALE_DOC_PATTERNS:
                if pattern in text:
                    offenders.append(f"{path.relative_to(ROOT)} contains {pattern}")

    if offenders:
        joined = "\n".join(f"- {item}" for item in offenders)
        raise RuntimeError(f"stale generated documentation references found:\n{joined}")


def main() -> int:
    for generator in GENERATORS:
        run_generator(generator)

    validate_no_stale_paths()
    print("Generated docs and validated generated-reference paths.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
