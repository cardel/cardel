#!/usr/bin/env bash
# luz-calida.sh -- alterna la luz calida de noche. Se llama desde SUPER+O.
#
# Usa hyprsunset. El estado va en un archivo y no consultando al demonio, y la
# razon esta medida: despues de `hyprctl hyprsunset identity`, la consulta
# `hyprctl hyprsunset temperature` sigue respondiendo el ultimo valor fijado
# (4000), asi que no distingue encendido de apagado.
#
# Al encender se guarda la temperatura que habia para devolverla despues, en vez
# de imponer un numero fijo.
#
# Ojo al grabar o editar video: con la luz calida encendida los colores que ves
# en pantalla no son los del archivo.
set -euo pipefail

MARCA="${XDG_RUNTIME_DIR:-/tmp}/luz-calida"
CALIDA=4000

if [[ -f "$MARCA" ]]; then
  previa="$(cat -- "$MARCA" 2>/dev/null || true)"
  [[ "$previa" =~ ^[0-9]+$ ]] || previa=6000
  hyprctl hyprsunset temperature "$previa" >/dev/null
  rm -f -- "$MARCA"
  notify-send -u low -i weather-clear "Luz normal" "${previa} K"
else
  actual="$(hyprctl hyprsunset temperature 2>/dev/null || true)"
  [[ "$actual" =~ ^[0-9]+$ ]] || actual=6000
  printf '%s' "$actual" >"$MARCA"
  hyprctl hyprsunset temperature "$CALIDA" >/dev/null
  notify-send -u low -i weather-clear-night "Luz calida" "${CALIDA} K"
fi
