#!/usr/bin/env bash
# install.sh -- symlink this folder's overrides.conf into the Hyprland config.
#
#   overrides.conf -> $XDG_CONFIG_HOME/hypr/user_configs/overrides.conf
#   gromit.sh      -> ~/.local/bin/gromit.sh
#
# Run from this directory:  ./install.sh
# Resolves its own path so the source repo can live anywhere on disk.
#
# Por que solo overrides.conf y no toda la carpeta: el resto de archivos de
# ~/.config/hypr (hyprbinds.conf, hyprvars.conf, hyprland.conf...) los genera y
# actualiza la distribucion de Hyprland que hay instalada, y no se versionan
# aqui a proposito. Este repo solo lleva las decisiones propias, que es lo que
# ese archivo esta pensado para contener.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_FILE="$SRC_DIR/overrides.conf"
DST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/user_configs"
DST_FILE="$DST_DIR/overrides.conf"

if [[ ! -f "$SRC_FILE" ]]; then
  echo "error: $SRC_FILE not found" >&2
  exit 1
fi

if [[ ! -d "$DST_DIR" ]]; then
  echo "error: $DST_DIR no existe -- instala primero Hyprland y su config base" >&2
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

# gromit.sh es lo que llaman los binds de gromit en overrides.conf. Va a
# ~/.local/bin porque es donde Hyprland resuelve los scripts de los binds sin
# ruta (volume.sh, refresh.sh, brightness.sh viven ahi): la distribucion lo pone
# en el PATH del compositor. Un bind con un nombre que no resuelve falla en
# silencio, asi que si esta carpeta no existe se crea, no se avisa y se sigue.
BIN_DIR="$HOME/.local/bin"
mkdir -p -- "$BIN_DIR"
if [[ -e "$BIN_DIR/gromit.sh" && ! -L "$BIN_DIR/gromit.sh" ]]; then
  backup="$BIN_DIR/gromit.sh.bak.$(date +%Y%m%d-%H%M%S)"
  mv -- "$BIN_DIR/gromit.sh" "$backup"
  echo "backed up existing script -> $backup"
fi
ln -sfn -- "$SRC_DIR/gromit.sh" "$BIN_DIR/gromit.sh"
echo "linked $BIN_DIR/gromit.sh -> $SRC_DIR/gromit.sh"

# overrides.conf termina con `source = local.conf`, y un source que apunta a un
# archivo inexistente es un error de configuracion en Hyprland -- comprobado en
# 0.56.2, y un comodin tampoco lo salva. En una maquina nueva hay que crearlo
# aunque quede vacio; ahi va lo que dependa del hardware (que monitor tiene cada
# escritorio, el mapeo de la tableta grafica) y por eso no se versiona.
LOCAL_FILE="$DST_DIR/local.conf"
if [[ ! -e "$LOCAL_FILE" ]]; then
  cat > "$LOCAL_FILE" <<'LOCALEOF'
# Configuracion local de esta maquina. NO se versiona.
#
# Aqui va lo que depende del hardware concreto: monitores, mapeo de la tableta
# grafica, dispositivos de entrada. overrides.conf lo carga con `source`.
LOCALEOF
  echo "created $LOCAL_FILE (vacio, requerido por el source de overrides.conf)"
else
  echo "kept existing $LOCAL_FILE"
fi
