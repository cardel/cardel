#!/usr/bin/env bash
# install.sh -- enlaza los dos archivos de waybar que no dependen de la maquina.
#
#   modules.json -> $XDG_CONFIG_HOME/waybar/modules.json
#   style.css    -> $XDG_CONFIG_HOME/waybar/style.css
#
# Se ejecuta desde este directorio:  ./install.sh
# Resuelve su propia ruta, asi que el repo puede vivir en cualquier sitio.
#
# Que NO se versiona, y por que:
#
#   configs/config.json, configs/config_laptop.json -- son los que eligen que
#   modulos salen y en que orden, y hay uno por maquina; ~/.config/waybar/config
#   es un enlace al que toque. Es el mismo caso que el bloque de monitores de
#   hypr/overrides.conf: versionarlo obligaria a elegir una de las dos maquinas.
#
#   ~/.cache/wal/colors-waybar.css -- lo genera pywal en cada cambio de tema y
#   style.css lo importa con @import. Es cache, no configuracion.
#
# Enlazar aqui SI es seguro, al contrario que foot.ini: refresh.sh toca waybar
# (`pkill waybar; waybar &`, linea 136) pero solo lo reinicia, no reescribe
# ningun archivo con `>`, y no hay plantilla de pywal que apunte a estos dos.
# Comprobado antes de poner el enlace.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"

if [[ ! -d "$DST_DIR" ]]; then
  echo "error: $DST_DIR no existe -- instala primero waybar y su config base" >&2
  exit 1
fi

for archivo in modules.json style.css; do
  src="$SRC_DIR/$archivo"
  dst="$DST_DIR/$archivo"

  if [[ ! -f "$src" ]]; then
    echo "error: $src no existe" >&2
    exit 1
  fi

  # Si habia un archivo de verdad (no un enlace), se respalda con fecha.
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    backup="$dst.bak.$(date +%Y%m%d-%H%M%S)"
    mv -- "$dst" "$backup"
    echo "respaldado $dst -> $backup"
  fi

  ln -sfn -- "$src" "$dst"
  echo "enlazado $dst -> $src"
done

# waybar relee la configuracion con SIGUSR2; no hace falta cerrar la sesion.
# SIGUSR1 NO sirve aqui: esa es la que oculta y muestra la barra (SUPER+B).
if pgrep -x waybar >/dev/null 2>&1; then
  pkill -SIGUSR2 -x waybar || true
  echo "waybar recargada (SIGUSR2)"
else
  echo "waybar no esta corriendo; se aplicara al arrancarla"
fi
