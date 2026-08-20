#!/usr/bin/env bash
# comprobar.sh -- dice en que estado esta esta maquina para compartir la camara.
#
#   ./comprobar.sh
#
# Pensado para lanzarlo tal cual en una maquina nueva (el PC de mesa) antes de
# tocar nada: no cambia nada, solo mira. Los numeros de /dev/videoN y los ids de
# los nodos de PipeWire cambian de una maquina a otra, asi que aqui no hay nada
# fijado a mano.
set -euo pipefail

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; }
no()   { printf '  \033[31mNO\033[0m    %s\n' "$1"; }
info() { printf '        %s\n' "$1"; }

echo "== Camaras fisicas =="
if command -v v4l2-ctl >/dev/null; then
  v4l2-ctl --list-devices 2>/dev/null | sed 's/^/  /' || info "ninguna"
  # El nodo bueno es el que anuncia Video Capture en Device Caps; los demas
  # suelen ser Metadata Capture, que no dan imagen.
  for d in /dev/video*; do
    [[ -e "$d" ]] || continue
    caps="$(v4l2-ctl -d "$d" --info 2>/dev/null | sed -n '/Device Caps/,$p')"
    if grep -q 'Video Capture' <<<"$caps"; then info "$d -> da imagen"
    elif grep -q 'Video Output' <<<"$caps"; then info "$d -> salida (camara virtual)"
    else info "$d -> solo metadatos, no da imagen"
    fi
  done
else
  no "falta v4l-utils (v4l2-ctl), sin el no se puede comprobar nada de esto"
fi

echo
echo "== Camino 1: PipeWire (compartir de verdad, sin root) =="
nodo="$(wpctl status 2>/dev/null | sed -n '/^Video/,/^Settings/p' \
        | sed -n '/Sources:/,/Filters:/p' | grep -oE '^ *[|│ ]*\*? *[0-9]+\.' \
        | tr -dc '0-9\n' | head -1)"
if [[ -n "${nodo:-}" ]]; then
  ok "PipeWire expone la camara como Video/Source (nodo $nodo)"
  info "eso es lo que permite que dos programas la lean a la vez"
else
  no "PipeWire no expone ninguna camara; sin esto el camino 1 no existe"
fi

if [[ -e /usr/lib/obs-plugins/linux-pipewire.so ]]; then
  ok "OBS trae el plugin de PipeWire"
  info 'fuente a elegir: "Video Capture Device (PipeWire)" (BETA)'
else
  no "OBS sin plugin de PipeWire: solo podra abrir /dev/videoN en exclusiva"
fi

if busctl --user get-property org.freedesktop.portal.Desktop \
     /org/freedesktop/portal/desktop org.freedesktop.portal.Camera \
     IsCameraPresent 2>/dev/null | grep -q true; then
  ok "el portal de camara (xdg-desktop-portal) ve una camara"
else
  no "el portal de camara no responde; el navegador no podra pedirla por ahi"
fi

estado_flag="no activado"
ls_chromium="$HOME/.config/chromium/Local State"
if [[ -f "$ls_chromium" ]] && grep -q 'enable-webrtc-pipewire-camera@1' "$ls_chromium" 2>/dev/null; then
  estado_flag="activado"
fi
if [[ "$estado_flag" == "activado" ]]; then
  ok "Chromium: flag enable-webrtc-pipewire-camera activado"
elif [[ -f "$ls_chromium" ]]; then
  no "Chromium: falta el flag enable-webrtc-pipewire-camera  ->  ./navegadores.sh"
else
  info "Chromium: sin perfil en esta maquina, nada que hacer"
fi

# Firefox: el pref se pone en user.js, que gana sobre prefs.js en cada arranque.
perfiles_ff=()
if [[ -d "$HOME/.mozilla/firefox" ]]; then
  while IFS= read -r ruta; do
    [[ -d "$HOME/.mozilla/firefox/$ruta" ]] && perfiles_ff+=("$HOME/.mozilla/firefox/$ruta")
  done < <(grep -oP '^Path=\K.*' "$HOME/.mozilla/firefox/profiles.ini" 2>/dev/null || true)
fi
if [[ ${#perfiles_ff[@]} -eq 0 ]]; then
  info "Firefox: sin perfiles en esta maquina, nada que hacer"
else
  con=0
  for pf in "${perfiles_ff[@]}"; do
    grep -qs 'media.webrtc.camera.allow-pipewire' "$pf/user.js" && con=$((con + 1))
  done
  if [[ "$con" -eq ${#perfiles_ff[@]} ]]; then
    ok "Firefox: media.webrtc.camera.allow-pipewire puesto en los $con perfiles"
  elif [[ "$con" -gt 0 ]]; then
    no "Firefox: solo $con de ${#perfiles_ff[@]} perfiles  ->  ./navegadores.sh"
  else
    no "Firefox: falta media.webrtc.camera.allow-pipewire  ->  ./navegadores.sh"
  fi
fi

echo
echo "== Camino 2: v4l2loopback (camara falsa que rellena OBS) =="
if pacman -Q v4l2loopback-dkms &>/dev/null; then
  ok "v4l2loopback-dkms instalado"
else
  no "falta v4l2loopback-dkms  ->  ./install.sh"
fi
if lsmod | grep -q '^v4l2loopback'; then
  ok "modulo cargado"
else
  no "modulo no cargado  ->  ./install.sh"
fi
if [[ -e /etc/modprobe.d/v4l2loopback.conf ]]; then
  if cmp -s "$(dirname -- "${BASH_SOURCE[0]}")/etc/modprobe.d/v4l2loopback.conf" \
            /etc/modprobe.d/v4l2loopback.conf; then
    ok "/etc/modprobe.d/v4l2loopback.conf al dia"
  else
    no "/etc/modprobe.d/v4l2loopback.conf difiere del repo  ->  ./install.sh"
  fi
else
  no "/etc/modprobe.d/v4l2loopback.conf ausente  ->  ./install.sh"
fi

echo
echo "== Microfono =="
ok "no hay nada que hacer: PipeWire lo comparte solo (ver README)"
