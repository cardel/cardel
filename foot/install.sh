#!/usr/bin/env bash
# install.sh -- enlaza la configuracion de foot de este directorio.
# Ejecutar desde aqui:  ./install.sh
# Resuelve su propia ruta, asi que el repositorio puede vivir donde sea.
#
# Este instalador NO enlaza en ~/.config/foot/foot.ini, y no es un descuido.
# Cuando la maquina trae el montaje de JaKooLit, ~/.local/bin/refresh.sh genera
# ese archivo concatenando cuatro y redirigiendo con `>`:
#
#   cat defaults.ini overrides.ini ~/.cache/wal/foot.base.ini \
#       overrides_colors.ini > foot.ini
#
# `>` sigue los symlinks (medido), asi que enlazar foot.ini haria que el primer
# refresco escribiera la salida de pywal dentro del repositorio, sin romper el
# enlace y sin avisar. El destino correcto es overrides_colors.ini: es el
# ultimo de la concatenacion y en foot gana la ultima aparicion de cada clave
# (tambien medido), de modo que esta configuracion se impone sobre pywal.
#
# En una maquina sin ese montaje no hay nada que concatenar y se enlaza
# foot.ini directamente.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_FILE="$SRC_DIR/foot.ini"
DST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/foot"

if [[ ! -f "$SRC_FILE" ]]; then
  echo "error: no encuentro $SRC_FILE" >&2
  exit 1
fi

# Validar antes de instalar. foot devuelve 230 si hay una opcion que no existe;
# una configuracion rota no da error al arrancar, foot se queda con los valores
# de fabrica y el problema pasa por "el tema no se aplico".
if command -v foot >/dev/null 2>&1; then
  if ! foot --check-config -c "$SRC_FILE"; then
    echo "error: foot rechaza $SRC_FILE; no se instala nada" >&2
    exit 1
  fi
  echo "foot --check-config: correcto"
else
  echo "aviso: foot no esta instalado; se enlaza sin validar" >&2
fi

mkdir -p "$DST_DIR"

# ¿Esta la maquina con el montaje que genera foot.ini?
if [[ -f "$DST_DIR/defaults.ini" ]]; then
  DST_FILE="$DST_DIR/overrides_colors.ini"
  GENERADO="si"
  echo "detectado el montaje que genera foot.ini (defaults.ini presente)"
else
  DST_FILE="$DST_DIR/foot.ini"
  GENERADO="no"
  echo "montaje simple: se enlaza foot.ini directamente"
fi

# Si ya hay un archivo de verdad, se guarda antes de sustituirlo.
if [[ -e "$DST_FILE" && ! -L "$DST_FILE" ]]; then
  respaldo="$DST_FILE.bak.$(date +%Y%m%d-%H%M%S)"
  mv -- "$DST_FILE" "$respaldo"
  echo "respaldo del anterior -> $respaldo"
fi

ln -sfn -- "$SRC_FILE" "$DST_FILE"
echo "enlazado $DST_FILE -> $SRC_FILE"

# Con el montaje de JaKooLit, foot solo lee foot.ini: hay que rehacerlo ahora o
# la configuracion no llega hasta el proximo refresco del tema. Se arma con las
# mismas piezas y en el mismo orden que refresh.sh, saltando las que no existan
# (cat aborta la que falta pero sigue, y aqui no interesa ensuciar la salida).
if [[ "$GENERADO" == "si" ]]; then
  piezas=()
  for p in "$DST_DIR/defaults.ini" \
           "$DST_DIR/overrides.ini" \
           "$HOME/.cache/wal/foot.base.ini" \
           "$DST_DIR/overrides_colors.ini"; do
    [[ -e "$p" ]] && piezas+=("$p")
  done
  # foot.ini es un archivo normal, nunca un enlace: aqui `>` es seguro.
  if [[ -L "$DST_DIR/foot.ini" ]]; then
    echo "error: $DST_DIR/foot.ini es un symlink; refresh.sh escribiria a traves de el." >&2
    echo "       borralo y vuelve a ejecutar este instalador." >&2
    exit 1
  fi
  # foot.ini es reproducible (sale de las piezas), pero es barato guardarlo.
  if [[ -f "$DST_DIR/foot.ini" ]]; then
    cp -- "$DST_DIR/foot.ini" "$DST_DIR/foot.ini.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  cat "${piezas[@]}" > "$DST_DIR/foot.ini"
  echo "regenerado $DST_DIR/foot.ini a partir de ${#piezas[@]} piezas"
  if command -v foot >/dev/null 2>&1; then
    foot --check-config -c "$DST_DIR/foot.ini" || true
  fi
fi

echo
echo "Las ventanas de foot que ya esten abiertas no cambian: la configuracion"
echo "se lee al arrancar. Abre una nueva para verlo."
