#!/bin/bash
# ============================================================
# generate-pdf.sh v2 — Markdown + Mermaid → PDF
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'
log() { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---- Defaults ----
DOCS_DIR="docs"
OUTPUT_DIR="output"
BUILD_DIR="/tmp/pdf-build"
GENERATE_INDIVIDUAL=false
INCLUDE_SECURITY=false
TITLE="Plataforma de Datos — Documentación Técnica"
SUBTITLE="Arquitectura, Despliegue y Operación sobre Kubernetes/AWS"
AUTHOR="Carlos A Delgado (cardel)"
FOOTER_TEXT="Documento Confidencial"
HEADER_LEFT="Plataforma de Datos"
MERMAID_THEME="neutral"
MERMAID_WIDTH=1200
EXCLUDE_PATTERNS=""

# ---- Buscar puppeteer config ----
PCFG=""
for p in /etc/mermaid-puppeteer.json /etc/puppeteer-config.json; do
  [ -f "$p" ] && PCFG="$p" && break
done
if [ -z "$PCFG" ]; then
  PCFG="/tmp/mermaid-puppeteer.json"
  echo '{"executablePath":"/usr/bin/chromium","args":["--no-sandbox","--disable-setuid-sandbox","--disable-dev-shm-usage","--disable-gpu","--single-process"]}' >"$PCFG"
fi

# ---- Help ----
show_help() {
  cat <<'HELP'
generate-pdf — Markdown + Mermaid → PDF

USO:  generate-pdf [opciones]

  --docs-dir DIR         Directorio con .md (default: docs)
  --output DIR           Salida (default: output)
  --individual           Generar PDFs individuales
  --include-security     Incluir 06-AVISO-SEGURIDAD.md
  --exclude PATTERN      Excluir archivos (repetible)
  --title TEXT           Título portada
  --subtitle TEXT        Subtítulo
  --author TEXT          Autor
  --header TEXT          Encabezado
  --footer TEXT          Pie de página
  --mermaid-theme THEME  neutral|default|dark|forest
  --help
HELP
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --docs-dir)
    DOCS_DIR="$2"
    shift 2
    ;;
  --output)
    OUTPUT_DIR="$2"
    shift 2
    ;;
  --individual)
    GENERATE_INDIVIDUAL=true
    shift
    ;;
  --include-security)
    INCLUDE_SECURITY=true
    shift
    ;;
  --exclude)
    EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS}|$2"
    shift 2
    ;;
  --title)
    TITLE="$2"
    shift 2
    ;;
  --subtitle)
    SUBTITLE="$2"
    shift 2
    ;;
  --author)
    AUTHOR="$2"
    shift 2
    ;;
  --header)
    HEADER_LEFT="$2"
    shift 2
    ;;
  --footer)
    FOOTER_TEXT="$2"
    shift 2
    ;;
  --mermaid-theme)
    MERMAID_THEME="$2"
    shift 2
    ;;
  --help | -h) show_help ;;
  *)
    err "Opción desconocida: $1"
    exit 1
    ;;
  esac
done

# ---- Validar ----
[ ! -d "$DOCS_DIR" ] && err "No existe: ${DOCS_DIR}" && exit 1
MD_COUNT=$(find "$DOCS_DIR" -maxdepth 1 -name "*.md" | wc -l)
[ "$MD_COUNT" -eq 0 ] && err "Sin archivos .md en ${DOCS_DIR}" && exit 1
log "Encontrados ${MD_COUNT} archivos Markdown en ${DOCS_DIR}/"

rm -rf "$BUILD_DIR"
mkdir -p "${BUILD_DIR}/images" "${OUTPUT_DIR}"

# Guardar directorio de trabajo original (antes de cualquier cd)
SAVED_PWD="$(pwd)"

# ============================================================
# FASE 1: Mermaid → SVG
# ============================================================
log "Fase 1: Procesando diagramas Mermaid..."

# Diagnosticar Chromium/Puppeteer antes de renderizar
log "Verificando Chromium..."
CHROMIUM_PATH=$(which chromium 2>/dev/null || which chromium-browser 2>/dev/null || echo "")
if [ -n "$CHROMIUM_PATH" ]; then
  log "  Chromium: ${CHROMIUM_PATH}"
  $CHROMIUM_PATH --version 2>/dev/null || warn "  No se pudo obtener versión"
else
  warn "  Chromium no encontrado en PATH"
fi

# Test rápido de mmdc
echo 'graph LR; A-->B' >/tmp/_diag.mmd
set +e
DIAG_OUT=$(mmdc -i /tmp/_diag.mmd -o /tmp/_diag.svg -p "$PCFG" 2>&1)
DIAG_RC=$?
set -e
if [ $DIAG_RC -eq 0 ] && [ -s /tmp/_diag.svg ]; then
  log "  mmdc test: OK ($(wc -c </tmp/_diag.svg) bytes)"
else
  warn "  mmdc test FALLÓ (exit: ${DIAG_RC})"
  echo "$DIAG_OUT" | while IFS= read -r l; do warn "    ${l}"; done
fi
rm -f /tmp/_diag.*

TOTAL_MM=0
OK_MM=0

for md_file in "${DOCS_DIR}"/*.md; do
  [ -f "$md_file" ] || continue
  filename=$(basename "$md_file")

  # Extraer bloques mermaid → archivos .mmd, referenciar como PNG
  awk -v bd="${BUILD_DIR}" -v fn="${filename%.md}" '
  BEGIN { mm=0; mc=""; c=0 }
  /^```mermaid/ { mm=1; mc=""; next }
  /^```/ && mm {
    mm=0; c++
    mf = bd "/images/" fn "-mermaid-" c ".mmd"
    pf = "images/" fn "-mermaid-" c ".png"
    print mc > mf; close(mf)
    print "![Diagrama](" pf ")"; print ""; next
  }
  mm { mc = mc $0 "\n"; next }
  { print }
  ' "$md_file" >"${BUILD_DIR}/${filename}"
done

# Renderizar cada .mmd → PNG (no SVG — XeLaTeX maneja PNG sin problemas)
for mmd_file in "${BUILD_DIR}"/images/*.mmd; do
  [ -f "$mmd_file" ] || continue
  png_file="${mmd_file%.mmd}.png"
  mmd_name="$(basename "$mmd_file")"
  TOTAL_MM=$((TOTAL_MM + 1))

  # Renderizar como PNG a 2x escala (alta resolución para PDF)
  set +e
  MMDC_OUT=$(mmdc \
    -i "$mmd_file" \
    -o "$png_file" \
    -t "$MERMAID_THEME" \
    -b white \
    -p "$PCFG" \
    -s 2 \
    -w "$MERMAID_WIDTH" 2>&1)
  rc=$?
  set -e

  # Fallback: sin puppeteer config
  if [ $rc -ne 0 ] || [ ! -f "$png_file" ] || [ "$(wc -c <"$png_file" 2>/dev/null || echo 0)" -lt 500 ]; then
    set +e
    MMDC_OUT=$(mmdc \
      -i "$mmd_file" \
      -o "$png_file" \
      -t "$MERMAID_THEME" \
      -b white \
      -s 2 \
      -w "$MERMAID_WIDTH" 2>&1)
    rc=$?
    set -e
  fi

  if [ $rc -eq 0 ] && [ -f "$png_file" ] && [ "$(wc -c <"$png_file" 2>/dev/null || echo 0)" -gt 500 ]; then
    OK_MM=$((OK_MM + 1))
  else
    warn "Falló: ${mmd_name} (exit: ${rc})"
    echo "$MMDC_OUT" | head -5 | while IFS= read -r l; do warn "  ${l}"; done
    # Placeholder PNG: 1x1 pixel transparente (Pandoc lo ignora sin error)
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n\xb4\x00\x00\x00\x00IEND\xaeB`\x82' >"$png_file"
  fi
done

ok "${OK_MM}/${TOTAL_MM} diagramas renderizados"

# Limpiar emojis y caracteres Unicode problemáticos de los .md procesados
# XeLaTeX con Noto Sans no tiene: emojis (🔴⚠✅❌📄🎨📦🚀🏷️📋📥🖨️),
# flechas especiales (→←↔), y otros símbolos.
log "Limpiando caracteres Unicode no soportados por LaTeX..."
for md_file in "${BUILD_DIR}"/*.md; do
  [ -f "$md_file" ] || continue
  sed -i \
    -e 's/🔴/[!]/g' \
    -e 's/⚠️\?/[!]/g' \
    -e 's/✅/[OK]/g' \
    -e 's/❌/[X]/g' \
    -e 's/📄/*/g' \
    -e 's/📦/*/g' \
    -e 's/📋/*/g' \
    -e 's/📥/*/g' \
    -e 's/📤/*/g' \
    -e 's/📂/*/g' \
    -e 's/📑/*/g' \
    -e 's/🖨️\?/*/g' \
    -e 's/🚀/*/g' \
    -e 's/🏷️\?/*/g' \
    -e 's/🎨/*/g' \
    -e 's/🐳/*/g' \
    -e 's/🔗/*/g' \
    -e 's/🔑/*/g' \
    -e 's/🏗️\?/*/g' \
    -e 's/→/->/g' \
    -e 's/←/<-/g' \
    -e 's/↔/<->/g' \
    -e 's/—/--/g' \
    -e 's/✔/[OK]/g' \
    -e 's/✗/[X]/g' \
    -e 's/⚡/*/g' \
    -e 's/️//g' \
    "$md_file"
done

# ============================================================
# FASE 2: Metadata Pandoc
# ============================================================
log "Fase 2: Generando metadata..."
DATE=$(date +'%Y-%m-%d' 2>/dev/null || echo "2026")

# IMPORTANTE:
# - NO usar titlepage-color, titlepage-text-color (son de Eisvogel, no Pandoc)
# - NO usar toccolor con hex (causa error xcolor)
# - NO cargar xcolor en header-includes (Pandoc ya lo carga)
# - Colores de links: usar nombres base LaTeX (red, blue, black, etc.)
cat >"${BUILD_DIR}/metadata.yaml" <<METAEOF
---
title: "${TITLE}"
subtitle: "${SUBTITLE}"
author:
  - "${AUTHOR}"
date: "${DATE}"
lang: es
toc: true
toc-depth: 3
colorlinks: true
linkcolor: blue
urlcolor: blue
citecolor: blue
geometry:
  - top=2.5cm
  - bottom=2.5cm
  - left=2.5cm
  - right=2.5cm
fontsize: 11pt
numbersections: true
header-includes:
  - \usepackage{fancyhdr}
  - \pagestyle{fancy}
  - \fancyhead[L]{\small ${HEADER_LEFT}}
  - \fancyhead[R]{\small \thepage}
  - \fancyfoot[C]{\small ${FOOTER_TEXT}}
  - \renewcommand{\headrulewidth}{0.4pt}
  - \renewcommand{\footrulewidth}{0.2pt}
  - \usepackage{xurl}
  - \setlength{\tabcolsep}{4pt}
  - \renewcommand{\arraystretch}{1.3}
  - \let\oldlongtable\longtable
  - \renewcommand{\longtable}{\small\oldlongtable}
---
METAEOF

ok "Metadata generada"

# ============================================================
# FASE 3: Seleccionar documentos
# ============================================================
log "Fase 3: Seleccionando documentos..."
FILES=()

for f in "${BUILD_DIR}"/0*.md; do
  [ -f "$f" ] || continue
  fn=$(basename "$f")

  if [[ "$fn" == "06-AVISO-SEGURIDAD.md" && "$INCLUDE_SECURITY" == "false" ]]; then
    warn "Excluyendo: ${fn} (usar --include-security)"
    continue
  fi

  if [ -n "$EXCLUDE_PATTERNS" ]; then
    SKIP=false
    IFS='|' read -ra PATS <<<"${EXCLUDE_PATTERNS#|}"
    for pat in "${PATS[@]}"; do
      [ -z "$pat" ] && continue
      [[ "$fn" == $pat ]] && SKIP=true && break
    done
    $SKIP && warn "Excluyendo: ${fn}" && continue
  fi

  FILES+=("$f")
  log "  ✅ ${fn}"
done

[ ${#FILES[@]} -eq 0 ] && err "Sin documentos" && exit 1
ok "${#FILES[@]} documentos seleccionados"

# ============================================================
# FASE 4: PDF consolidado
# ============================================================
log "Fase 4: Generando PDF consolidado..."

# Resolver OUTPUT_DIR a ruta absoluta
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
OUTPUT_PDF="${OUTPUT_DIR}/documentacion-plataforma-datos.pdf"

cd "${BUILD_DIR}"

set +e
PANDOC_OUT=$(pandoc \
  metadata.yaml \
  "${FILES[@]}" \
  --from markdown \
  --to pdf \
  --pdf-engine=xelatex \
  --resource-path=. \
  --highlight-style=tango \
  --table-of-contents \
  --toc-depth=3 \
  --number-sections \
  --columns=80 \
  --wrap=auto \
  -V mainfont="Noto Sans" \
  -V monofont="Liberation Mono" \
  -V mathfont="Noto Sans Math" \
  -V 'mainfontoptions=BoldFont=Noto Sans Bold, ItalicFont=Noto Sans Italic' \
  -o "${OUTPUT_PDF}" 2>&1)
PANDOC_RC=$?
set -e

cd "$SAVED_PWD"

if [ $PANDOC_RC -eq 0 ] && [ -f "$OUTPUT_PDF" ] && [ "$(wc -c <"$OUTPUT_PDF")" -gt 0 ]; then
  ok "PDF consolidado: ${OUTPUT_PDF} ($(du -h "$OUTPUT_PDF" | cut -f1))"
else
  err "Pandoc falló (exit: ${PANDOC_RC})"
  echo "$PANDOC_OUT" | tail -20
  err "--- Fin del error de Pandoc ---"
  exit 1
fi

# ============================================================
# FASE 5: PDFs individuales (opcional)
# ============================================================
if [ "$GENERATE_INDIVIDUAL" = true ]; then
  log "Fase 5: PDFs individuales..."
  INDIV_DIR="${OUTPUT_DIR}/individual"
  mkdir -p "$INDIV_DIR"
  cd "${BUILD_DIR}"

  for md in "${FILES[@]}"; do
    fn=$(basename "$md")
    pdfn="${fn%.md}.pdf"

    set +e
    pandoc "$md" \
      --from markdown --to pdf --pdf-engine=xelatex \
      --resource-path=. --highlight-style=tango --number-sections \
      -V mainfont="Noto Sans" -V monofont="Liberation Mono" \
      -V geometry:margin=2.5cm -V fontsize=11pt \
      -o "${INDIV_DIR}/${pdfn}" 2>&1 | tail -3
    irc=$?
    set -e

    [ $irc -eq 0 ] && log "  ✅ ${pdfn}" || warn "  ⚠️  ${fn}"
  done

  cd "$SAVED_PWD"
  ok "$(find "$INDIV_DIR" -name '*.pdf' | wc -l) PDFs individuales"
fi

# ============================================================
# Resumen
# ============================================================
echo ""
echo "============================================"
ok "Completado"
echo "  📄 Consolidado: ${OUTPUT_PDF}"
[ "$GENERATE_INDIVIDUAL" = true ] && echo "  📂 Individual:  ${OUTPUT_DIR}/individual/"
echo "  🎨 Mermaid:     ${OK_MM}/${TOTAL_MM}"
echo "  📑 Documentos:  ${#FILES[@]}"
echo "============================================"
