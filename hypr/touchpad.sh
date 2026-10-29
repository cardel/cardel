#!/usr/bin/env bash
# touchpad.sh -- activa y desactiva el touchpad. Se llama desde el bind de
# XF86TouchpadToggle (Fn + F10 en este TUF).
#
#   touchpad.sh        alterna
#   touchpad.sh -r     vuelve a aplicar el estado guardado
#
# POR QUE SE REESCRIBIO
#
# El de la distribucion movia una variable de configuracion:
#
#     hyprctl keyword "\$TOUCHPAD_ENABLED" "true" -r
#
# y user_configs/touchpad.conf la usaba en el bloque device. Las variables de
# configuracion murieron con el formato .conf en Hyprland 0.57, asi que esa
# linea no hace nada. Las dos salidas que parecian obvias tampoco sirven, y las
# dos estan medidas en 0.57.0:
#
#     hyprctl keyword 'device[nombre]:enabled' false   -> "unknown request"
#     hl.device({ ..., enabled = false }) en caliente  -> no se refleja
#
# Lo que queda es lo que hace este guion: dejar el estado en un archivo, que la
# configuracion lee al cargar, y pedir una recarga. El bloque device vive en
# overrides.lua y el nombre del dispositivo en maquina.lua, porque cambia de un
# equipo a otro.
#
# El archivo de estado esta en XDG_RUNTIME_DIR, que se borra al cerrar sesion:
# cada sesion empieza con el touchpad activo, que es lo que uno quiere.
set -euo pipefail

ESTADO="${XDG_RUNTIME_DIR:-/tmp}/touchpad.status"

leer() {
  # Sin archivo, activo. Cualquier cosa que no sea "false" cuenta como activo.
  [[ -f "$ESTADO" ]] || { printf 'true'; return; }
  local v
  v="$(cat -- "$ESTADO")"
  [[ "$v" == "false" ]] && printf 'false' || printf 'true'
}

aplicar() {
  # La recarga es lo que de verdad aplica el cambio: la configuracion vuelve a
  # leer el archivo de estado. `config-only` evita rehacer los monitores, que no
  # tiene nada que ver con esto y parpadea.
  hyprctl reload config-only >/dev/null
}

avisar() {
  if [[ "$1" == "true" ]]; then
    notify-send -u low -i input-touchpad "Touchpad activado"
  else
    notify-send -u low -i input-touchpad "Touchpad desactivado"
  fi
}

case "${1:-}" in
-r)
  # Volver a aplicar lo guardado, sin avisar y sin alternar.
  aplicar
  ;;
"")
  if [[ "$(leer)" == "true" ]]; then nuevo=false; else nuevo=true; fi
  printf '%s' "$nuevo" >"$ESTADO"
  aplicar
  avisar "$nuevo"
  ;;
*)
  echo "uso: $(basename -- "$0") [-r]" >&2
  exit 1
  ;;
esac
