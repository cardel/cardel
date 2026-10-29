#!/usr/bin/env bash
# modo-grabacion.sh -- alterna el modo grabacion. Se llama desde SUPER+G.
#
# Apaga animaciones, blur, sombra y wobble mientras grabas clase con OBS: la
# captura sale limpia, el codificador no pelea con efectos que nadie va a ver en
# el video, y la GPU no se calienta de adorno. Si asusctl esta instalado, de
# paso pone el perfil de ventilador silencioso, que es lo que arruina el audio.
#
# El mecanismo es el mismo del touchpad, y por la misma razon: en 0.57 no se
# puede cambiar la configuracion en caliente (`hyprctl keyword` responde
# "unknown request"). Asi que el estado vive en un archivo, hyprance.lua lo lee
# al cargar y aqui se pide una recarga.
set -euo pipefail

MARCA="${XDG_RUNTIME_DIR:-/tmp}/modo-grabacion"

perfil() {
  command -v asusctl >/dev/null 2>&1 || return 0
  asusctl profile -P "$1" >/dev/null 2>&1 || true
}

if [[ -f "$MARCA" ]]; then
  rm -f -- "$MARCA"
  hyprctl reload config-only >/dev/null
  perfil Balanced
  notify-send -u low -i media-record "Modo grabacion apagado" "Vuelven animaciones, blur y sombras"
else
  : >"$MARCA"
  hyprctl reload config-only >/dev/null
  perfil Quiet
  notify-send -u low -i media-record "Modo grabacion encendido" "Sin animaciones ni efectos, ventilador silencioso"
fi
