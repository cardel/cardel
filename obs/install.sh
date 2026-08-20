#!/usr/bin/env bash
# install.sh -- deja lista la camara virtual de OBS (v4l2loopback).
#
#   ./install.sh
#
# A diferencia del resto de instaladores de este repo, este NO enlaza: copia.
# Los dos archivos van a /etc, son de root y los lee el kernel al arrancar.
# Un symlink desde /etc/modprobe.d hacia un repo dentro de $HOME significaria
# que cualquier cosa que corra como el usuario puede cambiar los parametros con
# los que se carga un modulo del kernel; y /etc/modules-load.d lo lee
# systemd-modules-load.service muy temprano, antes de que $HOME tenga por que
# estar montado. Se copia, y se reinstala cuando cambie el archivo del repo.
#
# Pide sudo para las copias y para instalar el paquete si falta.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
VIDEO_NR=10   # tiene que coincidir con video_nr= en etc/modprobe.d/v4l2loopback.conf

# --- dependencias ---------------------------------------------------------
if ! pacman -Q obs-studio &>/dev/null; then
  echo "aviso: obs-studio no esta instalado (pacman -S obs-studio)" >&2
fi

if ! pacman -Q v4l2loopback-dkms &>/dev/null; then
  echo "falta v4l2loopback-dkms; instalandolo"
  # linux-headers hace falta para que dkms compile el modulo contra este kernel.
  sudo pacman -S --needed v4l2loopback-dkms linux-headers
fi

# --- archivos de /etc -----------------------------------------------------
copiar() {
  local src="$1" dst="$2"
  if [[ ! -f "$src" ]]; then
    echo "error: $src no existe" >&2
    exit 1
  fi
  if [[ -e "$dst" ]] && cmp -s "$src" "$dst"; then
    echo "sin cambios  $dst"
    return
  fi
  if [[ -e "$dst" ]]; then
    local backup
    backup="$dst.bak.$(date +%Y%m%d-%H%M%S)"
    sudo cp -a -- "$dst" "$backup"
    echo "respaldado  $dst -> $backup"
  fi
  sudo install -D -m 644 -o root -g root -- "$src" "$dst"
  echo "copiado     $dst"
}

copiar "$SRC_DIR/etc/modprobe.d/v4l2loopback.conf"     /etc/modprobe.d/v4l2loopback.conf
copiar "$SRC_DIR/etc/modules-load.d/v4l2loopback.conf" /etc/modules-load.d/v4l2loopback.conf

# --- cargar ahora, sin reiniciar ------------------------------------------
# Si ya estaba cargado con otros parametros hay que recargarlo: modprobe no
# reaplica las opciones sobre un modulo que ya esta dentro del kernel.
if lsmod | grep -q '^v4l2loopback'; then
  if fuser -s "/dev/video$VIDEO_NR" 2>/dev/null; then
    echo "aviso: /dev/video$VIDEO_NR esta en uso; cierra OBS y el navegador y" >&2
    echo "       vuelve a lanzar este script para recargar el modulo" >&2
  else
    sudo modprobe -r v4l2loopback
    sudo modprobe v4l2loopback
    echo "modulo recargado"
  fi
else
  sudo modprobe v4l2loopback
  echo "modulo cargado"
fi

# --- comprobar ------------------------------------------------------------
# Que el modulo cargue no prueba nada: lo que importa es que exista el nodo y
# que anuncie el nombre correcto, que es lo que vera Zoom en su desplegable.
if [[ -e "/dev/video$VIDEO_NR" ]]; then
  echo
  v4l2-ctl -d "/dev/video$VIDEO_NR" --info 2>/dev/null | grep -E 'Card type|Driver name' || true
  echo "listo: /dev/video$VIDEO_NR"
  echo "en OBS:  Herramientas > Iniciar camara virtual"
  echo "en Zoom: camara = OBS Virtual Camera"
else
  echo "error: el modulo cargo pero /dev/video$VIDEO_NR no existe" >&2
  echo "       revisa video_nr= en etc/modprobe.d/v4l2loopback.conf" >&2
  exit 1
fi
