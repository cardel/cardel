#!/usr/bin/env bash
# install.sh -- symlink the XDG default-application config into place.
#
#   mimeapps.list            -> $XDG_CONFIG_HOME/mimeapps.list
#   applications/*.desktop   -> $XDG_DATA_HOME/applications/
#
# Run from this directory:  ./install.sh
# Resolves its own path so the source repo can live anywhere on disk.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS_DIR="$DATA_HOME/applications"

stamp="$(date +%Y%m%d-%H%M%S)"

# Back up a real (non-symlink) file before replacing it, then link.
link() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mv -- "$dst" "$dst.bak.$stamp"
    echo "backed up -> $dst.bak.$stamp"
  fi
  ln -sfn -- "$src" "$dst"
  echo "linked $dst -> $src"
}

mkdir -p -- "$CONF_HOME" "$APPS_DIR"

# handlr and xdg-mime both write here, so once it is a symlink your default
# applications stay tracked in the repo -- `handlr set` will show up in git status.
link "$SRC_DIR/mimeapps.list" "$CONF_HOME/mimeapps.list"

for desktop in "$SRC_DIR"/applications/*.desktop; do
  [[ -e "$desktop" ]] || continue
  link "$desktop" "$APPS_DIR/$(basename -- "$desktop")"
done

# The .desktop cache is what makes MimeType= lines resolvable; without this the
# new entry is ignored until something else happens to rebuild it.
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR"
  echo "rebuilt desktop database in $APPS_DIR"
else
  echo "note: update-desktop-database not found (pacman -S desktop-file-utils)"
fi

# ~/.local/bin/xdg-open shadows xdg-utils with a `handlr open` shim, so handlr is
# what actually resolves a MIME type here -- check it, not just xdg-mime.
if command -v handlr >/dev/null 2>&1; then
  echo "handlr inode/directory -> $(handlr get --json inode/directory 2>/dev/null || echo '(unresolved)')"
else
  echo "note: handlr is not installed, but ~/.local/bin/xdg-open calls it"
fi
