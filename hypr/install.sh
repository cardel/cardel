#!/usr/bin/env bash
# install.sh -- enlaza la configuracion de Hyprland de este repo.
#
#   *.lua        -> $XDG_CONFIG_HOME/hypr/
#   gromit.sh    -> ~/.local/bin/gromit.sh
#   touchpad.sh  -> ~/.local/bin/touchpad.sh
#   refresh.sh   -> ~/.local/bin/refresh.sh
#   keybinds.sh  -> ~/.local/bin/keybinds.sh
#   modo-grabacion.sh -> ~/.local/bin/modo-grabacion.sh
#   hypridle.conf-> $XDG_CONFIG_HOME/hypr/hypridle.conf
#
# Se corre desde esta carpeta:  ./install.sh
# Resuelve su propia ruta, asi que el repo puede vivir donde sea.
#
# POR QUE AHORA ES TODA LA CONFIGURACION Y NO SOLO overrides.conf
#
# Hyprland 0.57.0 elimino el parser del formato .conf: la configuracion es Lua y
# nada mas. Al no encontrar hyprland.lua, el compositor genera uno de ejemplo y
# se queda con ese, asi que los diez .conf de la distribucion dejaron de leerse
# de golpe. Ya no hay un archivo base que la distribucion mantenga y uno propio
# encima: todo es propio, y por eso todo esta aqui.
#
# Lo unico que no se versiona es maquina.lua, con los monitores y los nombres de
# dispositivo del equipo. Este guion lo crea desde la plantilla si falta.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
BIN_DIR="$HOME/.local/bin"

MODULOS=(hyprland hyprvars hyprdevices hyprstart hyprsettings hyprules hyprbinds hyprance overrides)

if [[ ! -d "$DST_DIR" ]]; then
  echo "error: $DST_DIR no existe -- instala primero Hyprland" >&2
  exit 1
fi

# Enlaza $1 en $2, respaldando antes lo que haya si no es ya un enlace.
enlazar() {
  local src="$1" dst="$2"
  if [[ ! -e "$src" ]]; then
    echo "error: $src no existe" >&2
    exit 1
  fi
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local backup="$dst.bak.$(date +%Y%m%d-%H%M%S)"
    mv -- "$dst" "$backup"
    echo "respaldado $dst -> $backup"
  fi
  ln -sfn -- "$src" "$dst"
  echo "enlazado $dst -> $src"
}

for m in "${MODULOS[@]}"; do
  enlazar "$SRC_DIR/$m.lua" "$DST_DIR/$m.lua"
done

# Los scripts van a ~/.local/bin porque es donde Hyprland resuelve los nombres
# sin ruta de los binds y de los exec: hyprvars.lua mete esa carpeta en el PATH
# del compositor. Un bind con un nombre que no resuelve falla en silencio.
mkdir -p -- "$BIN_DIR"
enlazar "$SRC_DIR/gromit.sh" "$BIN_DIR/gromit.sh"
enlazar "$SRC_DIR/touchpad.sh" "$BIN_DIR/touchpad.sh"
enlazar "$SRC_DIR/refresh.sh" "$BIN_DIR/refresh.sh"
enlazar "$SRC_DIR/keybinds.sh" "$BIN_DIR/keybinds.sh"
enlazar "$SRC_DIR/modo-grabacion.sh" "$BIN_DIR/modo-grabacion.sh"

# hypridle lee su propia configuracion de ~/.config/hypr/hypridle.conf, en su
# formato, no en Lua.
enlazar "$SRC_DIR/hypridle.conf" "$DST_DIR/hypridle.conf"

# maquina.lua: overrides.lua lo carga con require y usa lo que devuelve, asi que
# tiene que existir. No se sobrescribe nunca, que para eso es local.
LOCAL_FILE="$DST_DIR/maquina.lua"
if [[ ! -e "$LOCAL_FILE" ]]; then
  cp -- "$SRC_DIR/maquina.lua.ejemplo" "$LOCAL_FILE"
  echo "creado $LOCAL_FILE desde la plantilla -- ajustalo antes de entrar a la sesion"
else
  echo "conservado $LOCAL_FILE"
fi

echo
echo "comprueba antes de entrar:  Hyprland --verify-config"
