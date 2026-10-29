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
PERFIL_PREVIO="${XDG_RUNTIME_DIR:-/tmp}/modo-grabacion.perfil"

# asusctl 6.5 usa subcomandos, no banderas: `profile get` y `profile set <x>`.
# Los perfiles de este TUF son Quiet, Balanced y Performance.
hay_asusctl() { command -v asusctl >/dev/null 2>&1; }

guardar_perfil() {
  hay_asusctl || return 0
  # "Active profile: Performance" -> "Performance"
  asusctl profile get 2>/dev/null | awk -F': ' '/Active profile/{print $2}' >"$PERFIL_PREVIO" || true
}

poner_perfil() {
  hay_asusctl || return 0
  [[ -n "$1" ]] && asusctl profile set "$1" >/dev/null 2>&1 || true
}

if [[ -f "$MARCA" ]]; then
  rm -f -- "$MARCA"
  hyprctl reload config-only >/dev/null
  # Devolver el perfil que habia antes, no uno inventado: este equipo puede
  # estar en Performance y bajarlo a Balanced en silencio seria una sorpresa.
  previo="$(cat -- "$PERFIL_PREVIO" 2>/dev/null || true)"
  poner_perfil "${previo:-Balanced}"
  rm -f -- "$PERFIL_PREVIO"
  notify-send -u low -i media-record "Modo grabacion apagado" "Vuelven los efectos y el perfil ${previo:-Balanced}"
else
  guardar_perfil
  : >"$MARCA"
  hyprctl reload config-only >/dev/null
  poner_perfil Quiet
  notify-send -u low -i media-record "Modo grabacion encendido" "Sin efectos, ventilador silencioso"
fi
