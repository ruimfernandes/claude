#!/usr/bin/env bash
# Install the Elixir-in-Docker tooling and start the image build in the
# background, so it bakes while the Claude session is already usable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_SRC="$SCRIPT_DIR/bin"
BIN_DEST="$HOME/.local/bin"

PROJECT_DIR="${BUILDEROS_PROJECT_DIR:-/home/dev/project}"

mkdir -p "$BIN_DEST"
install -m 0755 "$BIN_SRC/builderos-elixir-build" "$BIN_DEST/builderos-elixir-build"
install -m 0755 "$BIN_SRC/mix" "$BIN_DEST/mix"

# Ensure ~/.local/bin is on PATH for both shells so the wrapper shadows any mix.
PATH_LINE='case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -e "$rc" ] || touch "$rc"
  grep -qF '.local/bin' "$rc" || printf '\n# BuilderOS personalisation PATH\n%s\n' "$PATH_LINE" >> "$rc"
done

# Kick off the build asynchronously and return immediately. setsid + nohup
# detach it into its own session so it survives this script exiting and keeps
# building after the agent launches.
if [ -f "$PROJECT_DIR/backend/Dockerfile.dev" ]; then
  setsid nohup "$BIN_DEST/builderos-elixir-build" >/dev/null 2>&1 < /dev/null &
  echo "Elixir dev image build started in the background (log: ~/.cache/builderos-elixir/build.log)."
else
  echo "No $PROJECT_DIR/backend/Dockerfile.dev — Elixir image will build on first \`mix\` call if it appears."
fi
