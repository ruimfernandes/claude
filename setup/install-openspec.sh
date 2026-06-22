#!/usr/bin/env bash
# Install OpenSpec globally and make it runnable from anywhere — including
# /home/dev/project, whose .tool-versions pins Erlang/Elixir but not nodejs.
set -euo pipefail

ASDF_DIR="${ASDF_DIR:-$HOME/.asdf}"
TOOL_VERSIONS="$HOME/.tool-versions"

# asdf resolves a tool's version by walking up the directory tree, falling back
# to $HOME/.tool-versions. If no nodejs is pinned anywhere on that path, the
# node/npm/openspec shims error with "No version is set for command ...".
# Pin a global nodejs (highest installed) so the fallback always resolves.
if [ -d "$ASDF_DIR/installs/nodejs" ]; then
  node_ver="$(ls -1 "$ASDF_DIR/installs/nodejs" 2>/dev/null \
    | grep -E '^[0-9]+\.' | sort -V | tail -1 || true)"
  if [ -n "${node_ver:-}" ] && ! grep -qsE '^nodejs ' "$TOOL_VERSIONS"; then
    echo "nodejs $node_ver" >> "$TOOL_VERSIONS"
    echo "Pinned global nodejs $node_ver in $TOOL_VERSIONS"
  fi
fi

# Make sure asdf's shims/bin are reachable in this non-interactive shell.
export PATH="$ASDF_DIR/shims:$ASDF_DIR/bin:$PATH"

# Install OpenSpec into the asdf-managed global npm (no sudo — that would use a
# different, non-asdf node).
npm install -g @fission-ai/openspec@latest

# Refresh shims so the freshly installed `openspec` binary is picked up.
if command -v asdf >/dev/null 2>&1; then
  asdf reshim nodejs >/dev/null 2>&1 || true
fi

echo "OpenSpec installed: $(openspec --version 2>/dev/null || echo 'version check unavailable')"
