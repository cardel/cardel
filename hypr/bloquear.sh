#!/usr/bin/env bash
# bloquear.sh -- bloquea la pantalla con el primer bloqueador que sirva.
#
# POR QUE NO USA HYPRLOCK
#
# hyprlock 0.9.6 se lleva por delante la sesion entera con Hyprland 0.57.0. No
# es una sospecha: el historial de volcados llega hasta el 15 de mayo de 2026 y
# en todo ese tiempo hyprlock cayo dos veces, las dos el 29 de octubre, despues
# de que el compositor pasara de 0.56.2 a 0.57.0 esa misma mañana. Al caer se
# lleva a todos los clientes de Wayland: en el registro quedan, en el mismo
# segundo, hyprlock y hyprsunset abortando, el portal con SIGSEGV, "Error
# reading events from display: Broken pipe" y el kernel diciendo
# "NVRM: VM: invalid mmap context".
#
# hyprlock 0.9.6-3 es lo mas nuevo que hay en los repositorios, asi que no es
# cosa de actualizar. Cuando salga una version al dia con 0.57, se prueba y, si
# aguanta, se vuelve a poner primero en la lista de abajo.
#
# El orden es por madurez. Si no hay ninguno instalado, esto avisa y no hace
# nada: mas vale quedarse sin bloquear que perder la sesion.
set -euo pipefail

FONDO="$HOME/.cache/current_wallpaper.png"

intentar_swaylock() {
  command -v swaylock >/dev/null 2>&1 || return 1
  if [[ -f "$FONDO" ]]; then
    swaylock -f -i "$FONDO" -s fill
  else
    swaylock -f -c 1a1a1a
  fi
}

intentar_gtklock() { command -v gtklock >/dev/null 2>&1 && gtklock -d; }
intentar_waylock() { command -v waylock >/dev/null 2>&1 && waylock; }

for intento in intentar_swaylock intentar_gtklock intentar_waylock; do
  if "$intento"; then
    exit 0
  fi
done

notify-send -u critical -i system-lock-screen \
  "No hay bloqueador de pantalla" \
  "Instala swaylock. hyprlock esta descartado porque tumba la sesion con Hyprland 0.57."
exit 1
