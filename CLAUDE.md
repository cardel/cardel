# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal dotfiles for an **Arch Linux + Wayland** setup (Hyprland primary; i3/X11 supported as fallback). Each subdirectory is a self-contained configuration for one tool. There is no build system or package manager — configs are placed or symlinked manually.

## Repo structure

| Directory | Tool |
|-----------|------|
| `alacritty/` | Alacritty terminal emulator (TOML) |
| `tmux/` | tmux multiplexer |
| `config/oh-my-zsh/` | Zsh + Oh My Zsh |
| `config/i3/` | i3 window manager (X11 fallback) |
| `hypr/` | Hyprland compositor overrides |
| `zed/` | Zed editor (settings, keymap, themes) |
| `yazi/` | Yazi file manager |
| `pdfgithub/` | Markdown → PDF pipeline (pandoc + XeLaTeX + mermaid) |

`yazi/` is tracked in the repo.

## Key gotchas

### Terminal compatibility
`TERM=alacritty` is declared in both `alacritty/alacritty.toml` and `tmux/tmux.conf`. These must stay in sync — a mismatch silently breaks 24-bit truecolor, modifier keys, and focus events. Alacritty ≥ 0.13 is required (TOML schema; YAML configs are rejected).

### Font dependencies
- JetBrainsMono Nerd Font Mono (`ttf-jetbrains-mono-nerd` on Arch) — used by Alacritty and tmux
- IosevkaTerm Nerd Font — used by Zed
- Noto Sans, Liberation Mono, Noto Sans Math — required by the PDF pipeline

Missing fonts cause silent rendering failures (wrong glyphs, broken box-drawing).

### Clipboard
Alacritty and tmux prefer `wl-clipboard` (Wayland) or `xclip` (X11) for the `y` copy-mode keybind. OSC 52 clipboard works without them.

### PDF generation stack (`pdfgithub/`)
`generate-pdf.sh` requires: `pandoc`, `xelatex` (TeX Live), `mermaid-cli` (`mmdc`), and `chromium`. The Puppeteer config is read from `/etc/mermaid-puppeteer.json` or `/etc/puppeteer-config.json`; the script generates a fallback in `/tmp/` if neither exists. Use named colors only in LaTeX — hex values break `xcolor`.

## Shell scripts

Scripts use `set -euo pipefail`. Keep that pattern when adding new scripts.

## Adding new tool configs

There is no enforced install convention — some tools have an `install.sh` (symlink-based), others are placed manually. When adding a new tool, create a subdirectory named after the tool and add the config files there. An `install.sh` is optional.

## Language / locale

Zed's LSP spell-checking (`ltex`) is configured for **Spanish** (`es`). This is intentional.
