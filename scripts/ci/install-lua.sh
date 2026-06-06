#!/usr/bin/env bash
set -euo pipefail

brew update

if [ ! -x /opt/homebrew/bin/lua ]; then
  brew install lua
fi

/opt/homebrew/bin/lua -v
