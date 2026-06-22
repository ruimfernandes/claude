#!/usr/bin/env bash
# Install my git/mix aliases and wire them into the shell rc files.
set -euo pipefail

ALIAS_FILE="$HOME/.builderos_aliases"

cat > "$ALIAS_FILE" <<'EOF'
alias ss="git status"
alias ww="git checkout"
alias aa='git add .'
alias bb='git branch'
alias mf="mix format"
alias qd="git reset"
alias qddd="git reset --hard"
alias qee='git checkout -'
alias qgl='git log'
alias ql="git pull"
alias qp="git push"
alias qrb="git rebase"
alias qrbi="git rebase -i"
alias qst="git stash"
alias qstp="git stash pop"
EOF

# Source the alias file from each shell rc, idempotently.
SOURCE_LINE='[ -f "$HOME/.builderos_aliases" ] && . "$HOME/.builderos_aliases"'

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -e "$rc" ] || touch "$rc"
  if ! grep -qF ".builderos_aliases" "$rc"; then
    printf '\n# BuilderOS personalisation aliases\n%s\n' "$SOURCE_LINE" >> "$rc"
  fi
done

echo "Aliases written to $ALIAS_FILE and sourced from shell rc files."
