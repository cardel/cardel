#!/usr/bin/env bash
# install.sh -- enlaza la carpeta nvim/ de este repo en $HOME/.config/nvim
# Se ejecuta desde este directorio:  ./install.sh
# Resuelve su propia ruta, asi que el repo puede vivir en cualquier sitio.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_CONF="$SRC_DIR/nvim"
DST_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

if [[ ! -d "$SRC_CONF" ]]; then
  echo "error: no existe $SRC_CONF" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$DST_CONF")"

# Si ya hay una configuracion real (no un enlace), se respalda antes de tocarla.
# Importante: lazy-lock.json vive dentro de la config, asi que el respaldo
# conserva la instantanea exacta de plugins que habia antes de este cambio.
if [[ -e "$DST_CONF" && ! -L "$DST_CONF" ]]; then
  backup="$DST_CONF.bak.$(date +%Y%m%d-%H%M%S)"
  mv -- "$DST_CONF" "$backup"
  echo "respaldada la config anterior -> $backup"
fi

ln -sfn -- "$SRC_CONF" "$DST_CONF"
echo "enlazado $DST_CONF -> $SRC_CONF"

# yamllint no lee nada desde nvim: busca su configuracion por su cuenta, primero
# en el proyecto y si no en ~/.config/yamllint/config. Sin este archivo las
# reglas de fabrica marcan "missing document start" en casi cualquier YAML.
YAMLLINT_DST="${XDG_CONFIG_HOME:-$HOME/.config}/yamllint"
mkdir -p -- "$YAMLLINT_DST"
if [[ -e "$YAMLLINT_DST/config" && ! -L "$YAMLLINT_DST/config" ]]; then
  echo "aviso: ya existe $YAMLLINT_DST/config y no es un enlace; se deja como esta" >&2
else
  ln -sfn -- "$SRC_DIR/yamllint/config" "$YAMLLINT_DST/config"
  echo "enlazado $YAMLLINT_DST/config -> $SRC_DIR/yamllint/config"
fi

# El estado (plugins descargados, herramientas de mason) NO se versiona: vive en
# ~/.local/share/nvim y se reconstruye desde lazy-lock.json y las declaraciones
# de mason.ensure_installed. Por eso hace falta una pasada de sincronizacion.
if ! command -v nvim >/dev/null 2>&1; then
  echo "aviso: nvim no esta instalado (pacman -S neovim)" >&2
  exit 0
fi

# El lockfile no sobrevive al primer arranque en una maquina limpia, asi que se
# guarda una copia antes de tocar nada.
#
# Por que: la spec de LazyVim se importa desde el plugin LazyVim, que hay que
# clonar primero, asi que lazy.nvim instala en varias rondas
# ("while M.install_missing() do" en lazy/core/loader.lua). Cada ronda termina
# llamando a Lock.update(), que vacia la tabla del lockfile en memoria y la
# reescribe con lo que ya hay en disco. En la segunda ronda ya no queda entrada
# para los plugins que faltan, y el checkout se va al HEAD de la rama.
#
# Medido en un entorno limpio: de 60 plugins, 25 quedaron en el commit fijado
# (los de la primera ronda, LazyVim incluido) y 35 en HEAD.
#
# Devolver el lockfile y correr restore despues arregla las dos cosas de golpe:
# restore si respeta el archivo, y con todo ya clonado alcanza -- restore solo
# toca plugins instalados (filtra por plugin._.installed).
LOCK="$SRC_CONF/lazy-lock.json"
LOCK_BAK=""
if [[ -f "$LOCK" ]]; then
  LOCK_BAK="$(mktemp)"
  cp -- "$LOCK" "$LOCK_BAK"
fi

echo "instalando plugins (lazy.nvim)..."
nvim --headless "+Lazy! install" +qa

if [[ -n "$LOCK_BAK" ]]; then
  cp -- "$LOCK_BAK" "$LOCK"
  rm -f -- "$LOCK_BAK"
  echo "fijando cada plugin al commit del lockfile..."
  nvim --headless "+Lazy! restore" +qa
fi

# mason instala bajo demanda: las herramientas de ensure_installed al cargar
# mason.nvim (de forma asincrona, o sea que un headless se muere antes) y los
# servidores LSP recien al abrir un archivo de ese tipo. mason-bootstrap.lua
# calcula la lista completa desde la configuracion y la instala de una vez, para
# que los fallos aparezcan aqui y no dentro de un mes al abrir un .java.
echo "instalando servidores y herramientas de mason..."
nvim --headless -c "luafile $SRC_DIR/mason-bootstrap.lua" -c qa

echo
echo "listo. Faltan dos servidores que no vienen por mason:"
echo "  raco pkg install racket-langserver     (Racket)"
echo "  abre un .scala y ejecuta :MetalsInstall (Scala; usa coursier)"
