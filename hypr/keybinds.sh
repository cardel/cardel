#!/usr/bin/env bash
# keybinds.sh -- arma la tabla de atajos que muestra el menu de acciones.
#
#   ~/.cache/dots/keybinds.txt   tres columnas: modificadores, tecla, para que
#
# La lee el menu de SUPER+A (dots/menus/default.json, opcion "Keybinds"), que la
# pasa a fuzzel como lista de solo lectura.
#
# POR QUE SE REESCRIBIO
#
# El de la distribucion parseaba hyprbinds.conf y user_configs/* con una
# cascada de sed y awk que recortaba cada linea por el nombre del dispatcher.
# Hyprland 0.57 ya no lee esos archivos, asi que la tabla se quedo congelada en
# lo que decian cuando se migro a Lua.
#
# Ahora se lo pregunta al compositor, que es la unica fuente que no se desvia:
# `hyprctl binds` entrega cada bind con su mascara de modificadores, su tecla y
# su descripcion. Las descripciones las lleva la configuracion en el campo
# description de cada hl.bind.
#
# De paso desaparece el enredo de los unbind: el compositor ya reporta solo los
# binds que quedaron vivos, asi que no hay que emular a mano que un unbind
# borre el bind anterior.
set -euo pipefail

CACHE="$HOME/.cache/dots"
OUTPUT="$CACHE/keybinds.txt"
mkdir -p -- "$CACHE"

# jq no tiene operadores de bits, asi que cada modificador se prueba dividiendo.
# El orden es el que usaba la tabla vieja: SUPER CTRL ALT SHIFT.
#
# Las teclas por codigo salen con key vacio y keycode puesto. Los codigos 10 a
# 18 son los numeros 1 a 9 de la fila de arriba, que es como los usa la
# configuracion; cualquier otro se muestra como code:N.
hyprctl binds -j | jq -r '
  def bit(m; v): ((m / v) | floor) % 2 == 1;
  def mods(m):
    [ (if bit(m; 64) then "SUPER" else empty end),
      (if bit(m; 4)  then "CTRL"  else empty end),
      (if bit(m; 8)  then "ALT"   else empty end),
      (if bit(m; 1)  then "SHIFT" else empty end) ] | join(" ");
  def tecla:
    if .keycode != 0 then
      (if .keycode >= 10 and .keycode <= 18 then ((.keycode - 9) | tostring)
       else "code:\(.keycode)" end)
    else .key end;
  .[]
  | select((.description // "") != "")
  | [ mods(.modmask), tecla, .description ]
  | @tsv
' | sort -u | column -t -s "$(printf '\t')" > "$OUTPUT"

echo "$(wc -l < "$OUTPUT") atajos en $OUTPUT"
