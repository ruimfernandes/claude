#!/usr/bin/env bash
# Install the skills bundled in this repo (skills/) into ~/.claude/skills.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
SKILLS_DEST="$HOME/.claude/skills"

if [ ! -d "$SKILLS_SRC" ]; then
  echo "No skills/ directory at $SKILLS_SRC — nothing to copy." >&2
  exit 0
fi

mkdir -p "$SKILLS_DEST"
cp -a "$SKILLS_SRC/." "$SKILLS_DEST/"

# Drop any macOS cruft that may have been committed.
find "$SKILLS_DEST" -name '.DS_Store' -delete 2>/dev/null || true

echo "Skills synced into $SKILLS_DEST"
