#!/usr/bin/env bash
# mic-virtual.sh -- microfono virtual para mandar el audio de OBS a Zoom.
#
#   ./mic-virtual.sh on      crea el dispositivo
#   ./mic-virtual.sh off     lo quita
#   ./mic-virtual.sh status  dice si esta
#
# ESTO NO HACE FALTA PARA HABLAR. El microfono real se comparte solo: PipeWire
# abre ALSA una vez y mezcla a todos los clientes, asi que OBS y Zoom pueden
# grabarlo a la vez sin tocar nada (medido, ver README).
#
# Sirve para lo otro: que Zoom oiga lo que suena EN OBS -- un video que pones en
# clase, musica, la mezcla completa. Zoom web solo sabe leer de un microfono, asi
# que se le da uno falso cuyo contenido es la salida de OBS.
#
# Despues de encenderlo, en OBS:
#   Ajustes > Audio > Dispositivo de monitorizacion = OBS_Virtual_Mic
#   y en el mezclador, cada fuente que quieras enviar: "Monitorizar y emitir"
# y en Zoom, como microfono: "Monitor of OBS_Virtual_Mic".
set -euo pipefail

NOMBRE="obs_mic"
DESCRIPCION="OBS_Virtual_Mic"

indice_cargado() {
  # El indice del modulo si ya existe, vacio si no.
  pactl list short modules 2>/dev/null \
    | awk -v n="sink_name=$NOMBRE" '$2 == "module-null-sink" && index($0, n) { print $1; exit }'
}

case "${1:-status}" in
  on)
    if [[ -n "$(indice_cargado)" ]]; then
      echo "ya estaba encendido"
    else
      pactl load-module module-null-sink \
        sink_name="$NOMBRE" \
        sink_properties=device.description="$DESCRIPCION" >/dev/null
      echo "encendido"
    fi
    echo "en Zoom elige el microfono:  Monitor of $DESCRIPCION"
    ;;
  off)
    idx="$(indice_cargado)"
    if [[ -z "$idx" ]]; then
      echo "no estaba encendido"
    else
      pactl unload-module "$idx"
      echo "apagado"
    fi
    ;;
  status)
    if [[ -n "$(indice_cargado)" ]]; then
      echo "encendido -- en Zoom: Monitor of $DESCRIPCION"
    else
      echo "apagado"
    fi
    ;;
  *)
    echo "uso: $0 {on|off|status}" >&2
    exit 1
    ;;
esac
