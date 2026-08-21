#!/usr/bin/env bash
# comprobar.sh -- dice en que estado esta esta maquina para compartir camara y
# microfono entre OBS, los navegadores y Zoom.
#
#   ./comprobar.sh
#
# No cambia nada, solo mira. Pensado para lanzarlo tal cual en una maquina nueva
# antes de tocar nada. Los numeros de /dev/videoN y los ids de los nodos de
# PipeWire cambian de una maquina a otra, asi que aqui no hay nada fijado.
set -euo pipefail

# pactl y wpctl traducen sus etiquetas segun el locale y aqui se buscan por
# nombre en ingles.
export LC_ALL=C

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; }
no()   { printf '  \033[31mNO\033[0m    %s\n' "$1"; }
avi()  { printf '  \033[33m!!\033[0m    %s\n' "$1"; }
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
  info "eso es lo que permite que varios programas la lean a la vez"
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

echo
echo "== Navegadores =="
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
# Mismo orden y mismos campos que NAVEGADORES en navegadores.sh:
#   etiqueta | directorio bajo ~/.config | proceso | binario
for entrada in \
  "Chromium|chromium|chromium|/usr/lib/chromium/chromium" \
  "Vivaldi|vivaldi|vivaldi-bin|/opt/vivaldi/vivaldi-bin" \
  "Chrome|google-chrome|chrome|/opt/google/chrome/chrome" \
  "Brave|BraveSoftware/Brave-Browser|brave|/usr/lib/brave-bin/brave"
do
  IFS='|' read -r etiqueta dir proc bin <<<"$entrada"
  ls_file="$CONF/$dir/Local State"
  if [[ ! -f "$ls_file" ]]; then
    # Instalado sin estrenar y no instalado son cosas distintas: en el primer
    # caso solo falta abrirlo una vez para que se cree el perfil.
    if [[ -f "$bin" ]]; then
      info "$etiqueta: instalado pero sin perfil todavia (abrelo una vez)"
    else
      info "$etiqueta: no esta en esta maquina"
    fi
    continue
  fi
  if grep -qF 'enable-webrtc-pipewire-camera@1' "$ls_file" 2>/dev/null; then
    ok "$etiqueta: flag enable-webrtc-pipewire-camera activado"
  else
    no "$etiqueta: falta el flag enable-webrtc-pipewire-camera  ->  ./navegadores.sh"
  fi
  # Si el navegador esta abierto, cualquier cambio se pierde al cerrarlo.
  pgrep -x "$proc" >/dev/null 2>&1 && info "$etiqueta: esta abierto ahora mismo; cierralo antes de ./navegadores.sh"
done

# Firefox: el pref se pone en user.js, que gana sobre prefs.js en cada arranque.
perfiles_ff=()
if [[ -d "$HOME/.mozilla/firefox" ]]; then
  while IFS= read -r ruta; do
    [[ -d "$HOME/.mozilla/firefox/$ruta" ]] && perfiles_ff+=("$HOME/.mozilla/firefox/$ruta")
  done < <(grep -oP '^Path=\K.*' "$HOME/.mozilla/firefox/profiles.ini" 2>/dev/null || true)
fi
if [[ ${#perfiles_ff[@]} -eq 0 ]]; then
  if command -v firefox >/dev/null 2>&1; then
    info "Firefox: instalado pero sin perfil todavia (abrelo una vez y cierralo)"
  else
    info "Firefox: no esta en esta maquina"
  fi
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
# Compartirlo es gratis: PipeWire abre ALSA una vez y mezcla a todos los
# clientes (medido, ver README). Lo que si falla en silencio es CUAL coge cada
# programa: el que no elige uno a mano se lleva el que este por defecto, y el
# micro de la webcam suele ganar por prioridad.
ok "compartirlo no necesita nada: PipeWire mezcla a todos los clientes"

if command -v pactl >/dev/null; then
  defecto="$(pactl get-default-source 2>/dev/null || true)"
  mapfile -t fuentes < <(pactl list sources short 2>/dev/null | awk '$2 !~ /\.monitor$/ {print $2}')

  if [[ ${#fuentes[@]} -eq 0 ]]; then
    no "PipeWire no ve ningun microfono"
  else
    info "microfonos disponibles (${#fuentes[@]}):"
    for f in "${fuentes[@]}"; do
      desc="$(pactl list sources 2>/dev/null \
              | awk -v n="Name: $f" '$0 ~ n {found=1} found && /Description:/ {sub(/^\s*Description: /,""); print; exit}')"
      if [[ "$f" == "$defecto" ]]; then
        printf '          \033[32m*\033[0m %s\n' "${desc:-$f}"
      else
        printf '            %s\n' "${desc:-$f}"
      fi
    done
    info "(* = el que se llevan los programas que no eligen a mano)"

    # El aviso concreto: hay mas de un micro y el elegido es el de la camara.
    if [[ ${#fuentes[@]} -gt 1 && "$defecto" == *[Ww]ebcam* ]]; then
      avi "el microfono por defecto es el de la WEBCAM, no el micro aparte"
      info "los navegadores y Zoom se lo llevaran sin avisar. Para cambiarlo:"
      info "  pactl set-default-source <nombre-del-micro-bueno>"
      info "(wireplumber lo recuerda entre reinicios)"
    fi
  fi
else
  info "sin pactl no se puede comprobar cual es el microfono por defecto"
fi
