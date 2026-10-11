#!/usr/bin/env bash
# arranque.sh -- recarga waybar una vez, cuando Hyprland ya esta listo.
#
# Se llama desde hypr/overrides.conf:
#
#     exec-once = waybar-arranque.sh
#
# y se enlaza en ~/.local/bin con ese nombre (lo hace waybar/install.sh), que es
# donde Hyprland resuelve los scripts de los binds y de los exec-once.
#
# POR QUE EXISTE
#
# La instancia de waybar que arranca con la sesion se queda a veces con el
# modulo de escritorios vivo pero vacio: no pinta ningun numero y no reacciona a
# los eventos de cambio de escritorio. Medido con grim: el centro de la barra no
# cambiaba ni un pixel al cambiar de escritorio. Una recarga lo arregla al
# instante, y cualquier instancia lanzada despues funciona bien.
#
# El mecanismo exacto NO esta identificado, y conviene decirlo en vez de
# inventarlo. Lo que si se descarto, midiendo: no es que falte el socket de
# comandos de Hyprland (que tarda 854 ms mas que el de eventos y waybar arranca
# en medio), porque sin ese socket waybar desactiva los DOS modulos de Hyprland
# y lo dice en el log -- y en el fallo real hyprland/window funcionaba. El
# detalle completo esta en README.md.
#
# Asi que esto no pretende arreglar la causa: espera a que el compositor este
# entero y le dice a waybar que se reconstruya, que es lo unico que se sabe que
# funciona. Es la misma receta que ya aplicaba sin querer `refresh.sh`
# (SUPER+Shift+R), que hace `pkill waybar; waybar &` y por eso la barra se
# arreglaba sola al cambiar de tema.
#
# Si algun dia se identifica la causa, esto sobra: quitar la linea de
# overrides.conf y este archivo.
set -euo pipefail

# 1) Esperar a que el socket de comandos responda de verdad, no solo a que
#    exista el archivo. 10 s de tope; si no contesta en ese tiempo, hay un
#    problema mayor que esta barra.
for _ in $(seq 1 100); do
  if hyprctl monitors -j >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

# 2) Esperar a que waybar exista. La lanza hyprstart.conf, que Hyprland lee
#    antes que overrides.conf, pero el orden de arranque real no esta
#    garantizado.
#
#    `pgrep -x` compara el nombre de proceso exacto, asi que no puede
#    confundirse con este mismo script (que se llama arranque.sh).
for _ in $(seq 1 100); do
  if pgrep -x waybar >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

if ! pgrep -x waybar >/dev/null 2>&1; then
  exit 0 # no hay barra que recargar; nada que hacer y nada que avisar
fi

# 3) Un margen para que waybar termine de construir sus modulos antes de
#    pedirle que los rehaga.
sleep 1.5

# SIGUSR2 recarga la configuracion. SIGUSR1 NO: esa oculta y muestra la barra, y
# es la que manda SUPER+B -- mandarla aqui dejaria la barra escondida al entrar.
pkill -SIGUSR2 -x waybar || true
