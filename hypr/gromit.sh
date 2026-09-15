#!/usr/bin/env bash
# gromit.sh -- manda ordenes a gromit-mpx desde los binds de Hyprland,
# arrancandolo antes si hace falta.
#
#   gromit.sh toggle       dibujar si/no; si gromit no corre, lo arranca ya dibujando
#   gromit.sh clear        borrar todos los trazos
#   gromit.sh visibility   ocultar/mostrar los trazos
#   gromit.sh undo         deshacer el ultimo trazo
#   gromit.sh redo         rehacer
#   gromit.sh quit         cerrar gromit
#
# Se enlaza en ~/.local/bin (hypr/install.sh), que es donde Hyprland busca los
# scripts que llaman los binds (volume.sh, refresh.sh, brightness.sh...).
#
# Por que existe: gromit tiene dos juegos de opciones que no se mezclan. Las de
# ARRANQUE (--active --key --undo-key --opacity --line --debug ...) y las de
# CONTROL de una instancia que ya corre (--toggle --clear --visibility --undo
# --redo --quit --reload). Pasar una de control sin instancia viva muere con
#
#   Unknown Option for Gromit-MPX startup: "--toggle"
#
# y sale 1 -- medido en gromit-mpx 1.9.0. Un bind que llame al flatpak con
# --toggle a pelo solo funciona si gromit ya esta corriendo, y como nada lo
# arrancaba, SUPER+C no hacia nada. Este script decide en cada pulsacion.
#
# --key none --undo-key none: se le quitan a gromit sus propias teclas (F9 y F8
# con modificadores). Las engancha con un grab de XWayland, que bajo Hyprland
# solo recibe pulsaciones mientras una ventana X tiene el foco; por eso "no
# funcionaban". Las mismas teclas las declara overrides.conf y llegan por aqui,
# tenga el foco quien lo tenga. Sin quitarselas a gromit quedarian dos capas, y
# con una ventana X enfocada F9 haria toggle dos veces, o sea nada. Medido con
# --debug: sin la opcion aparece `Grabbing hot key 'F9' from keyboard '3'`, con
# ella no.
set -euo pipefail

accion=${1:-toggle}

# El binario nativo si existe (gromit-mpx en pacman en otras distros, o
# compilado); si no, el flatpak, que es lo que hay en estas dos maquinas.
if command -v gromit-mpx >/dev/null; then
  gromit=(gromit-mpx)
else
  gromit=(flatpak run net.christianbeier.Gromit-MPX)
fi

# pgrep -x compara el nombre de proceso exacto. Bajo flatpak el proceso real se
# sigue llamando gromit-mpx (los bwrap que lo envuelven no cuentan): medido.
corriendo() { pgrep -x gromit-mpx >/dev/null; }

case "$accion" in
  toggle)
    if corriendo; then
      exec "${gromit[@]}" --toggle
    fi
    # setsid -f: que gromit no cuelgue del shell que Hyprland abrio para el bind,
    # ni del terminal si se prueba a mano. Arranca ya en modo dibujo (--active),
    # que es lo que se espera de la primera pulsacion. Tarda ~440 ms en aparecer
    # la ventana (medido), asi que no hace falta tenerlo residente con exec-once.
    setsid -f "${gromit[@]}" --active --key none --undo-key none >/dev/null 2>&1
    ;;
  clear|visibility|undo|redo|quit|reload)
    # Sin instancia no hay nada que borrar ni deshacer. Salir en silencio: el
    # error de un bind no lo ve nadie, y arrancar gromit solo para deshacer nada
    # seria peor.
    corriendo || exit 0
    exec "${gromit[@]}" "--$accion"
    ;;
  *)
    echo "uso: ${0##*/} toggle|clear|visibility|undo|redo|quit|reload" >&2
    exit 2
    ;;
esac
