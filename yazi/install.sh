#!/usr/bin/env bash
# install.sh -- symlink this folder's yazi/ config dir into $HOME/.config/yazi
# Run from this directory:  ./install.sh
# Resolves its own path so the source repo can live anywhere on disk.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_CONF="$SRC_DIR/yazi"
DST_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/yazi"

if [[ ! -d "$SRC_CONF" ]]; then
  echo "error: $SRC_CONF not found" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$DST_CONF")"

# If a real (non-symlink) config already exists, back it up before replacing.
if [[ -e "$DST_CONF" && ! -L "$DST_CONF" ]]; then
  backup="$DST_CONF.bak.$(date +%Y%m%d-%H%M%S)"
  mv -- "$DST_CONF" "$backup"
  echo "backed up existing config -> $backup"
fi

ln -sfn -- "$SRC_CONF" "$DST_CONF"
echo "linked $DST_CONF -> $SRC_CONF"

# yazi parses its config at startup and silently falls back to preset settings
# on error, so surface a bad config here instead of at first launch.
if command -v yazi >/dev/null 2>&1; then
  if YAZI_CONFIG_HOME="$SRC_CONF" yazi --version </dev/null >/dev/null 2>&1; then
    echo "config OK for $(yazi --version 2>/dev/null || echo yazi)"
  else
    echo "warning: yazi rejected this config:" >&2
    YAZI_CONFIG_HOME="$SRC_CONF" yazi --version </dev/null 2>&1 | head -8 >&2
    exit 1
  fi
else
  echo "note: yazi is not installed (pacman -S yazi)"
fi
