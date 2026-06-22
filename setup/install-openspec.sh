#!/usr/bin/env bash
# Install OpenSpec so its asdf shim resolves from anywhere — including
# /home/dev/project, whose .tool-versions may pin a nodejs version the base
# image doesn't have installed.
#
# asdf picks a tool's version by walking up from the cwd; a project-level
# .tool-versions pin wins over the global one. If that pinned nodejs isn't
# installed (image has e.g. 25.9.0 but the project pins 22.16.0), the shim
# errors. So: install the version the project pins, and install OpenSpec into
# THAT version's globals so the shim just works (no ASDF_NODEJS_VERSION prefix).
set -euo pipefail

ASDF_DIR="${ASDF_DIR:-$HOME/.asdf}"
PROJECT_DIR="${BUILDEROS_PROJECT_DIR:-/home/dev/project}"
TOOL_VERSIONS="$HOME/.tool-versions"

export PATH="$ASDF_DIR/bin:$ASDF_DIR/shims:$PATH"

# Target nodejs version: honour the project's pin if it has one, else the
# highest version already installed on the image.
proj_node=""
[ -f "$PROJECT_DIR/.tool-versions" ] && \
  proj_node="$(awk '$1=="nodejs"{print $2; exit}' "$PROJECT_DIR/.tool-versions" || true)"

if [ -n "$proj_node" ]; then
  node_ver="$proj_node"
else
  node_ver="$(ls -1 "$ASDF_DIR/installs/nodejs" 2>/dev/null \
    | grep -E '^[0-9]+\.' | sort -V | tail -1 || true)"
fi

if [ -z "${node_ver:-}" ]; then
  echo "Could not determine a nodejs version; OpenSpec not installed." >&2
  exit 1
fi

# Install the target version if the image doesn't already have it.
if [ ! -d "$ASDF_DIR/installs/nodejs/$node_ver" ]; then
  echo "Installing nodejs $node_ver via asdf (project pin not present on image)..."
  asdf install nodejs "$node_ver"
fi

# Ensure a global nodejs fallback so the shim also resolves outside the project.
grep -qsE '^nodejs ' "$TOOL_VERSIONS" || echo "nodejs $node_ver" >> "$TOOL_VERSIONS"

# Install OpenSpec into that version's global packages.
NODE_BIN="$ASDF_DIR/installs/nodejs/$node_ver/bin"
ASDF_NODEJS_VERSION="$node_ver" "$NODE_BIN/npm" install -g @fission-ai/openspec@latest

# Refresh shims so the `openspec` binary is picked up.
command -v asdf >/dev/null 2>&1 && asdf reshim nodejs >/dev/null 2>&1 || true

echo "OpenSpec installed under nodejs $node_ver."
ASDF_NODEJS_VERSION="$node_ver" "$NODE_BIN/openspec" --version 2>/dev/null \
  && echo "openspec verified" || echo "openspec version check unavailable"
