#!/usr/bin/env bash
# install.sh -- ejecuta los instaladores de cada herramienta.
#
#   ./install.sh                  lista lo que hay y que esta enlazado
#   ./install.sh nvim yazi        instala solo esos
#   ./install.sh --all            instala todos menos los marcados como manuales
#   ./install.sh --paquetes       dice que paquetes del sistema faltan
#   ./install.sh --paquetes-todos la orden de pacman entera, para una maquina nueva
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
  [obs]="obs/install.sh"
  [zed]="zed/install.sh"
)

# Fuera de --all: requieren una decision antes de sobrescribir, o sudo.
MANUALES=(zsh obs)

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
  [obs]="/etc/modprobe.d/v4l2loopback.conf"
  [zed]="$CONF/zed/settings.json"
)

# nombre -> lista de paquetes del sistema que esa herramienta da por hechos.
# Incluye pdfgithub, que no tiene instalador pero si dependencias.
declare -A LISTAS=(
  [alacritty]="alacritty/paquetes.txt"
  [tmux]="tmux/paquetes.txt"
  [nvim]="nvim/paquetes.txt"
  [yazi]="yazi/paquetes.txt"
  [xdg]="xdg/paquetes.txt"
  [hypr]="hypr/paquetes.txt"
  [zsh]="config/oh-my-zsh/paquetes.txt"
  [obs]="obs/paquetes.txt"
  [zed]="zed/paquetes.txt"
  [pdfgithub]="pdfgithub/paquetes.txt"
)

# Herramientas que se instalan copiando en vez de enlazando. Para estas, "no es
# un symlink" es lo correcto y no un aviso, asi que el estado se calcula
# comparando el contenido: interesa saber si la copia de /etc quedo desfasada
# respecto al repo. El porque de copiar esta en obs/README.md.
declare -A FUENTES=(
  [obs]="obs/etc/modprobe.d/v4l2loopback.conf"
)

# --- paquetes -------------------------------------------------------------
#
# Cada herramienta declara los suyos en su paquetes.txt, una fila por paquete:
#
#   paquete | como comprobarlo | para que sirve
#
# En la segunda columna: un nombre suelto se busca en el PATH, @font:X en
# fontconfig, @pacman:X se le pregunta a pacman, y vacio no se comprueba.
# Un ? delante del paquete lo marca opcional: se avisa aparte y no entra en la
# orden de pacman, porque no falta nada por no tenerlo.
#
# Nada de esto se instala solo: hace falta root, y aqui eso se pide siempre a
# mano. (zed/install.sh lleva su propia copia de este lector para poder
# ejecutarse suelto; si se toca el formato, hay que tocar los dos.)
presente() {
  local prueba="$1"
  [[ -z "$prueba" ]] && return 0
  case "$prueba" in
    @font:*)
      # Sin -q a proposito: con -q, grep cierra la tuberia en la primera
      # coincidencia, fc-list muere con SIGPIPE (141) y pipefail lo convierte
      # en fallo. Daba "falta" con la fuente instalada.
      fc-list : family 2>/dev/null | grep -i "${prueba#@font:}" >/dev/null
      ;;
    @pacman:*) pacman -Q "${prueba#@pacman:}" >/dev/null 2>&1 ;;
    *) command -v "$prueba" >/dev/null 2>&1 ;;
  esac
}

paquetes() {
  local solo_orden="${1:-no}"
  local -a todos=() faltan=() opcionales=()
  local n lista paquete prueba para opcional

  for n in $(printf '%s\n' "${!LISTAS[@]}" | sort); do
    lista="$ROOT/${LISTAS[$n]}"
    [[ -f "$lista" ]] || { echo "aviso: falta $lista" >&2; continue; }
    local -a faltan_aqui=()
    while IFS='|' read -r paquete prueba para; do
      [[ -z "$paquete" || "$paquete" == \#* ]] && continue
      opcional=no
      if [[ "$paquete" == \?* ]]; then opcional=si; paquete="${paquete#\?}"; fi
      [[ "$opcional" == no ]] && todos+=("$paquete")
      if ! presente "$prueba"; then
        if [[ "$opcional" == si ]]; then
          opcionales+=("$n|$paquete|$para")
        else
          faltan+=("$paquete")
          faltan_aqui+=("$paquete|$para")
        fi
      fi
    done < "$lista"
    if [[ "$solo_orden" == "no" && ${#faltan_aqui[@]} -gt 0 ]]; then
      echo "  $n:"
      local f
      for f in "${faltan_aqui[@]}"; do printf '    %-24s %s\n' "${f%%|*}" "${f#*|}"; done
    fi
  done

  # Sin duplicados, conservando el orden de aparicion.
  local -a unicos=()
  local p u repetido
  local -a origen=()
  if [[ "$solo_orden" == "si" ]]; then origen=("${todos[@]}"); else origen=("${faltan[@]}"); fi
  for p in "${origen[@]:-}"; do
    repetido=0
    for u in "${unicos[@]:-}"; do [[ "$u" == "$p" ]] && { repetido=1; break; }; done
    [[ "$repetido" == 0 ]] && unicos+=("$p")
  done

  if [[ ${#unicos[@]} -eq 0 ]]; then
    echo "  nada: esta todo lo necesario."
  else
    [[ "$solo_orden" == "no" ]] && echo
    echo "sudo pacman -S --needed ${unicos[*]}"
  fi

  if [[ "$solo_orden" == "no" && ${#opcionales[@]} -gt 0 ]]; then
    echo
    echo "Opcionales que tampoco estan. No hacen falta para que nada funcione:"
    local o resto
    for o in "${opcionales[@]}"; do
      resto="${o#*|}"
      printf '  %-24s [%s] %s\n' "${resto%%|*}" "${o%%|*}" "${resto#*|}"
    done
  fi
}

es_manual() {
  local n="$1"
  for m in "${MANUALES[@]}"; do [[ "$m" == "$n" ]] && return 0; done
  return 1
}

estado() {
  local n="$1" dst="${DESTINOS[$1]}"
  if [[ -n "${FUENTES[$n]:-}" ]]; then
    if [[ ! -e "$dst" ]]; then echo "ausente"
    elif cmp -s "$ROOT/${FUENTES[$n]}" "$dst"; then echo "copiado"
    else echo "COPIA DESFASADA"
    fi
    return
  fi
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
    printf '  %-11s %-22s %s%s\n' "$n" "$(estado "$n")" "${DESTINOS[$n]}" "$marca"
  done
  echo
  echo "Uso:  ./install.sh <nombre>...   |   ./install.sh --all"
  echo "      ./install.sh --paquetes  (que falta)   --paquetes-todos  (maquina nueva)"
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

if [[ "$1" == "--paquetes" ]]; then
  echo "Paquetes del sistema que faltan:"
  echo
  paquetes no
  exit 0
fi

if [[ "$1" == "--paquetes-todos" ]]; then
  # Para una maquina nueva: la orden entera, este o no instalado ya.
  paquetes si
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
