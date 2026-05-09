#!/usr/bin/env bash
# install.sh -- symlink this folder's tmux.conf into $HOME/.tmux.conf
# Run from this directory:  ./install.sh
# Resolves its own path so the source repo can live anywhere on disk.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_FILE="$SRC_DIR/tmux.conf"
DST_FILE="$HOME/.tmux.conf"

if [[ ! -f "$SRC_FILE" ]]; then
  echo "error: $SRC_FILE not found" >&2
  exit 1
fi

# If a non-symlink config already exists, back it up before replacing.
if [[ -e "$DST_FILE" && ! -L "$DST_FILE" ]]; then
  backup="$DST_FILE.bak.$(date +%Y%m%d-%H%M%S)"
  mv -- "$DST_FILE" "$backup"
  echo "backed up existing config -> $backup"
fi

ln -sfn -- "$SRC_FILE" "$DST_FILE"
echo "linked $DST_FILE -> $SRC_FILE"

if command -v tmux >/dev/null 2>&1 && [[ -n "${TMUX:-}" ]]; then
  tmux source-file "$DST_FILE" \; display-message "tmux.conf reloaded" 2>/dev/null || true
  echo "reloaded running tmux server"
fi
