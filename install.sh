#!/usr/bin/env bash
# install.sh -- ejecuta los instaladores de cada herramienta.
#
#   ./install.sh              lista lo que hay y que esta enlazado
#   ./install.sh nvim yazi    instala solo esos
#   ./install.sh --all        instala todos menos los marcados como manuales
#
# Cada subdirectorio trae su propio install.sh y sigue siendo utilizable por
# separado; esto solo evita tener que recorrerlos a mano en una maquina nueva.
#
# Por que hay una lista de "manuales": zsh queda fuera de --all a proposito.
# .zshrc acumula lineas que anaden otros instaladores (Google Cloud SDK,
# filen-cli, pyenv) y enlazarlo sin leer el respaldo pierde esa configuracion.
# Se instala nombrandolo explicitamente:  ./install.sh zsh
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# nombre -> ruta del instalador
declare -A INSTALADORES=(
  [alacritty]="alacritty/install.sh"
  [tmux]="tmux/install.sh"
  [nvim]="nvim/install.sh"
  [yazi]="yazi/install.sh"
  [xdg]="xdg/install.sh"
  [hypr]="hypr/install.sh"
  [zsh]="config/oh-my-zsh/install.sh"
)

# Fuera de --all: requieren una decision antes de sobrescribir.
MANUALES=(zsh)

# nombre -> ruta que deberia quedar enlazada, para el informe de estado
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
declare -A DESTINOS=(
  [alacritty]="$CONF/alacritty/alacritty.toml"
  [tmux]="$HOME/.tmux.conf"
  [nvim]="$CONF/nvim"
  [yazi]="$CONF/yazi"
  [xdg]="$CONF/mimeapps.list"
  [hypr]="$CONF/hypr/user_configs/overrides.conf"
  [zsh]="$HOME/.zshrc"
)

es_manual() {
  local n="$1"
  for m in "${MANUALES[@]}"; do [[ "$m" == "$n" ]] && return 0; done
  return 1
}

estado() {
  local dst="$1"
  if [[ -L "$dst" ]]; then echo "enlazado"
  elif [[ -e "$dst" ]]; then echo "COPIA (no enlazado)"
  else echo "ausente"
  fi
}

listar() {
  echo "Herramientas disponibles:"
  printf '  %-11s %-22s %s\n' "NOMBRE" "ESTADO" "DESTINO"
  for n in $(printf '%s\n' "${!INSTALADORES[@]}" | sort); do
    local marca=""
    es_manual "$n" && marca=" (fuera de --all)"
    printf '  %-11s %-22s %s%s\n' "$n" "$(estado "${DESTINOS[$n]}")" "${DESTINOS[$n]}" "$marca"
  done
  echo
  echo "Uso:  ./install.sh <nombre>...   |   ./install.sh --all"
}

ejecutar() {
  local n="$1" script="$ROOT/${INSTALADORES[$1]}"
  if [[ ! -x "$script" ]]; then
    echo "error: $script no existe o no es ejecutable" >&2
    return 1
  fi
  echo "=== $n ==="
  # Cada instalador resuelve su propia ruta, pero varios asumen que se ejecutan
  # desde su directorio, asi que se respeta esa forma de invocacion.
  ( cd -- "$(dirname -- "$script")" && ./"$(basename -- "$script")" )
  echo
}

if [[ $# -eq 0 ]]; then
  listar
  exit 0
fi

if [[ "$1" == "--all" ]]; then
  fallos=0
  for n in $(printf '%s\n' "${!INSTALADORES[@]}" | sort); do
    es_manual "$n" && { echo "=== $n: omitido (instalalo con ./install.sh $n) ==="; echo; continue; }
    ejecutar "$n" || { fallos=$((fallos + 1)); echo "  ^ fallo en $n, se continua" >&2; echo; }
  done
  [[ $fallos -eq 0 ]] || { echo "terminado con $fallos fallo(s)" >&2; exit 1; }
  exit 0
fi

for n in "$@"; do
  if [[ -z "${INSTALADORES[$n]:-}" ]]; then
    echo "error: '$n' no es una herramienta conocida" >&2
    listar
    exit 1
  fi
done
for n in "$@"; do ejecutar "$n"; done
