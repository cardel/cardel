---
name: generate-pdf
description: Run the pdfgithub Markdown→PDF pipeline. Use when asked to generate or rebuild a PDF from a Markdown source.
disable-model-invocation: false
---

The PDF generation pipeline lives in `pdfgithub/generate-pdf.sh`. It converts Markdown (with Mermaid diagrams) to a styled PDF via pandoc + XeLaTeX.

## Required dependencies

Before running, verify these are installed:
- `pandoc` — Markdown processing
- `xelatex` (TeX Live) — PDF typesetting
- `mmdc` (mermaid-cli) — renders Mermaid diagrams to PNG
- `chromium` — headless browser for Mermaid rendering
- Fonts: Noto Sans, Liberation Mono, Noto Sans Math

Check with: `which pandoc xelatex mmdc chromium`

## Puppeteer config

The script looks for Puppeteer config at `/etc/mermaid-puppeteer.json` or `/etc/puppeteer-config.json`. If neither exists, it auto-generates one in `/tmp/`. No manual setup needed unless Chromium is in a non-standard path.

## Usage

```bash
# From the repo root:
bash pdfgithub/generate-pdf.sh <input.md> [output.pdf]
```

## Common issues

- **LaTeX color errors** — use named colors only (e.g., `blue`, `teal`). Hex values break `xcolor`.
- **Mermaid diagram fails** — ensure `mmdc` is in PATH and Chromium is accessible. Try running `mmdc --version` to verify.
- **Unicode/emoji** — the script replaces emojis and special arrows with ASCII equivalents during build. This is intentional.
- **Font not found** — install `noto-fonts`, `ttf-liberation`, `texlive-fontsextra` on Arch.

## Docker alternative

A `pdfgithub/Dockerfile` provides a pre-built container with all dependencies. Use it on machines without a full TeX Live install:

```bash
docker build -t pdf-gen pdfgithub/
docker run --rm -v "$PWD":/work pdf-gen <input.md> <output.pdf>
```
