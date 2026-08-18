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

# `install` y no `sync`: instala lo que falte respetando lazy-lock.json y no
# actualiza a ciegas lo que ya estaba, que es justo lo que hace reproducible el
# lockfile. Para actualizar a proposito: :Lazy update
echo "instalando plugins que falten (lazy.nvim)..."
nvim --headless "+Lazy! install" +qa

# mason.nvim se carga de forma diferida y LazyVim solo declara `cmd = "Mason"`,
# asi que sin cargarlo antes el stub de :MasonInstall ni siquiera existe
# ("E492: Not an editor command"). Con el plugin cargado, MasonInstall bloquea
# hasta terminar en modo headless.
#
# Los adaptadores de Java (java-debug-adapter, java-test) no van en esta lista:
# los pide el extra lang.java por su cuenta en cuanto nvim-dap existe.
TOOLS=(debugpy bash-debug-adapter yamllint actionlint ltex-ls-plus taplo)
echo "instalando herramientas de mason: ${TOOLS[*]}"
nvim --headless "+Lazy! load mason.nvim" "+MasonInstall ${TOOLS[*]}" +qa ||
  echo "aviso: MasonInstall fallo en headless; abre nvim y usa :Mason" >&2

echo
echo "listo."
echo "Para Racket hace falta un paso mas, porque no esta en mason:"
echo "  raco pkg install racket-langserver"
