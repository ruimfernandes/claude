#!/usr/bin/env bash
# Install OpenSpec globally.
set -euo pipefail

# Try a normal global install first; fall back to sudo if the npm prefix
# isn't writable by the dev user.
if npm install -g @fission-ai/openspec@latest; then
  :
else
  echo "Global install failed without elevation — retrying with sudo." >&2
  sudo npm install -g @fission-ai/openspec@latest
fi

echo "OpenSpec installed: $(openspec --version 2>/dev/null || echo 'version check unavailable')"
