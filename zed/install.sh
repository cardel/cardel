#!/usr/bin/env bash
# install.sh -- enlaza la configuracion de Zed en $HOME/.config/zed
# Se ejecuta desde este directorio:  ./install.sh
# Resuelve su propia ruta, asi que el repo puede vivir donde sea.
#
# Se enlaza archivo por archivo, no el directorio entero: ~/.config/zed es
# tambien donde Zed deja cosas suyas, y llevarse el directorio completo al repo
# arrastraria estado que no toca versionar.
#
# Enlazar settings.json es seguro aunque Zed lo reescriba cuando se cambia algo
# desde la interfaz. Zed resuelve el symlink antes de escribir
# (crates/settings/src/settings_store.rs, canonicalize + atomic_write), de modo
# que el archivo del repo recibe el cambio y el enlace sobrevive. Es justo lo
# contrario de lo que hace Firefox con prefs.js, y por eso aqui si se enlaza.
set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"

ARCHIVOS=(settings.json keymap.json tasks.json debug.json)
DIRECTORIOS=(themes)

rojo() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
avi() { printf '\033[33m%s\033[0m\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# 1. Validar el JSONC antes de enlazar nada.
#
# Zed acepta comentarios y comas colgantes, asi que `python -m json.tool` no
# sirve: rechazaria archivos correctos. Y un settings.json invalido no da error
# visible, Zed se queda con los valores por defecto -- que es exactamente el
# fallo silencioso que se quiere evitar aqui.
# ---------------------------------------------------------------------------
validar() {
  python3 - "$1" <<'PY'
import json, sys

ruta = sys.argv[1]
texto = open(ruta, encoding="utf-8").read()

# Quitar comentarios respetando las cadenas: un "//" dentro de una cadena
# (una URL, por ejemplo) no es un comentario.
salida, i, n = [], 0, len(texto)
while i < n:
    c = texto[i]
    if c == '"':
        salida.append(c); i += 1
        while i < n:
            salida.append(texto[i])
            if texto[i] == '\\':
                i += 1
                if i < n:
                    salida.append(texto[i])
            elif texto[i] == '"':
                i += 1
                break
            i += 1
        continue
    if c == '/' and i + 1 < n and texto[i + 1] == '/':
        while i < n and texto[i] != '\n':
            i += 1
        continue
    if c == '/' and i + 1 < n and texto[i + 1] == '*':
        i = texto.find('*/', i + 2)
        i = n if i == -1 else i + 2
        continue
    salida.append(c); i += 1

limpio = ''.join(salida)

# Comas colgantes antes de } o ]
import re
limpio = re.sub(r',(\s*[}\]])', r'\1', limpio)

try:
    json.loads(limpio)
except json.JSONDecodeError as e:
    print(f"{ruta}: {e}", file=sys.stderr)
    sys.exit(1)
PY
}

for f in "${ARCHIVOS[@]}"; do
  if [[ ! -f "$SRC_DIR/$f" ]]; then
    rojo "error: falta $SRC_DIR/$f"
    exit 1
  fi
  if ! validar "$SRC_DIR/$f"; then
    rojo "error: $f no es JSON valido; no se enlaza nada"
    exit 1
  fi
done
echo "JSON valido: ${ARCHIVOS[*]}"

# ---------------------------------------------------------------------------
# 2. Enlazar
# ---------------------------------------------------------------------------
mkdir -p -- "$DST_DIR"

enlazar() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local backup
    backup="$dst.bak.$(date +%Y%m%d-%H%M%S)"
    mv -- "$dst" "$backup"
    echo "respaldado $dst -> $backup"
  fi
  ln -sfn -- "$src" "$dst"
  echo "enlazado $dst -> $src"
}

for f in "${ARCHIVOS[@]}"; do enlazar "$SRC_DIR/$f" "$DST_DIR/$f"; done
for d in "${DIRECTORIOS[@]}"; do
  [[ -d "$SRC_DIR/$d" ]] && enlazar "$SRC_DIR/$d" "$DST_DIR/$d"
done

# ---------------------------------------------------------------------------
# 3. Comprobar lo que la configuracion da por hecho.
#
# Nada de esto lo instala este script: son paquetes del sistema. Pero cada uno
# que falte convierte un bloque de settings.json en letra muerta sin que Zed
# diga nada, asi que se avisa aqui y no en mitad de una clase.
# ---------------------------------------------------------------------------
echo
echo "== Lo que espera esta configuracion =="

comprobar_binario() {
  local bin="$1" para="$2" paquete="$3"
  if command -v "$bin" >/dev/null 2>&1; then
    printf '  %-12s ok\n' "$bin"
  else
    printf '  %-12s FALTA -- %s\n' "$bin" "$para"
    avi "      pacman -S $paquete"
  fi
}

comprobar_binario latexmk  "compilar al guardar; sin el no se compila nada" texlive-binextra
comprobar_binario zathura  "ver el PDF y saltar a la linea (synctex)"       "zathura zathura-pdf-mupdf"
comprobar_binario chktex   "avisos de LaTeX en el editor"                   texlive-binextra
comprobar_binario texcount "la tarea 'LaTeX: contar palabras'"              texlive-binextra
comprobar_binario lazygit  "la tarea 'Lazygit' (space g g)"                 lazygit
comprobar_binario zeditor  "busqueda inversa: del PDF de vuelta al .tex"    zed

# La fuente falla en silencio: Zed pinta con otra y no lo dice.
if fc-list : family 2>/dev/null | grep -qi 'IosevkaTerm Nerd Font'; then
  printf '  %-12s ok\n' "fuente"
else
  printf '  %-12s FALTA -- IosevkaTerm Nerd Font; Zed pintara con otra sin avisar\n' "fuente"
  avi "      pacman -S ttf-iosevkaterm-nerd"
fi

# Las extensiones las instala Zed sola al arrancar, por auto_install_extensions.
# Aqui solo se informa de lo que hay ahora mismo.
EXT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zed/extensions/installed"
echo
echo "== Extensiones =="
for e in latex ltex dockerfile html log; do
  if [[ -d "$EXT_DIR/$e" ]]; then
    printf '  %-12s instalada\n' "$e"
  else
    printf '  %-12s la instalara Zed al arrancar\n' "$e"
  fi
done
if [[ ! -d "$EXT_DIR/ltex" ]]; then
  avi "  ojo: ltex descarga ~320 MB la primera vez (lleva su propio JRE)."
fi
