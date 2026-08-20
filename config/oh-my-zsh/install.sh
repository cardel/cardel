#!/usr/bin/env bash
# install.sh -- symlink this folder's .zshrc into $HOME/.zshrc
# Run from this directory:  ./install.sh
# Resolves its own path so the source repo can live anywhere on disk.
#
# AVISO antes de ejecutarlo: a diferencia de las demas configuraciones de este
# repo, .zshrc suele acumular lineas que anaden otros instaladores por su
# cuenta -- el SDK de Google Cloud, filen-cli, pyenv, nvm... Todas escriben al
# final del archivo. Al enlazar, esas lineas dejan de aplicarse.
#
# El respaldo de abajo las conserva, pero hay que ir a leerlo y decidir cuales
# se suben al repo. Comprobado en el portatil: su .zshrc y el del repo habian
# divergido en las dos direcciones (distinta lista de plugins de oh-my-zsh, y
# el portatil sin el `export TERMINAL=alacritty` que necesita el <C-;> de yazi).
# Enlazar sin mirar habria perdido trabajo de un lado o del otro.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_FILE="$SRC_DIR/.zshrc"
DST_FILE="$HOME/.zshrc"

if [[ ! -f "$SRC_FILE" ]]; then
  echo "error: $SRC_FILE not found" >&2
  exit 1
fi

# oh-my-zsh tiene que existir: la primera linea util de .zshrc hace source de
# $ZSH/oh-my-zsh.sh, y sin el la shell arranca con errores en cada terminal.
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "error: falta ~/.oh-my-zsh -- instalalo antes (pacman -S oh-my-zsh-git o el script oficial)" >&2
  exit 1
fi

# If a non-symlink config already exists, back it up before replacing.
if [[ -e "$DST_FILE" && ! -L "$DST_FILE" ]]; then
  backup="$DST_FILE.bak.$(date +%Y%m%d-%H%M%S)"
  cp -- "$DST_FILE" "$backup"
  echo "backed up existing config -> $backup"
  echo "  revisalo: puede tener lineas que otros instaladores anadieron al final"
fi

ln -sfn -- "$SRC_FILE" "$DST_FILE"
echo "linked $DST_FILE -> $SRC_FILE"
