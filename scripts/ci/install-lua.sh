#!/usr/bin/env bash
set -euo pipefail

if ! command -v lua >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install lua
fi

lua -v
