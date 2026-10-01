#!/usr/bin/env bash
# install.sh -- enlaza esta carpeta en $HOME/.config/scalafmt
# Se ejecuta desde este directorio:  ./install.sh
# Resuelve su propia ruta, asi que el repositorio puede vivir donde sea.
#
# Que es: la configuracion de scalafmt que usa Metals desde nvim. El enlace
# tiene que existir porque nvim/nvim/lua/plugins/scala.lua apunta a
# ~/.config/scalafmt/.scalafmt.conf por ruta absoluta; sin el, al guardar un
# .scala sale el menu "No .scalafmt.conf file detected" en cada :w.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DST_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/scalafmt"

if [[ ! -f "$SRC_DIR/.scalafmt.conf" ]]; then
  echo "error: $SRC_DIR/.scalafmt.conf not found" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$DST_CONF")"

# Si ya hay una configuracion de verdad (no un enlace), respaldarla.
if [[ -e "$DST_CONF" && ! -L "$DST_CONF" ]]; then
  backup="$DST_CONF.bak.$(date +%Y%m%d-%H%M%S)"
  mv -- "$DST_CONF" "$backup"
  echo "backed up existing config -> $backup"
fi

ln -sfn -- "$SRC_DIR" "$DST_CONF"
echo "linked $DST_CONF -> $SRC_DIR"
