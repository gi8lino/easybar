#!/usr/bin/env bash
set -euo pipefail

brew update

if ! command -v lua >/dev/null 2>&1; then
  brew install lua
fi

lua -v


