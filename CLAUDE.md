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
| `nvim/` | Neovim / LazyVim (config, plugins, `yamllint/config`) |
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

### yazi image/PDF preview (`yazi/`)
Requires `chafa` and `poppler` (`pdftoppm`). Alacritty implements no graphics protocol, and the adapter yazi picks on its own (`Wayland`) delegates to `ueberzugpp` — `Adapter::matches` decides from `XDG_SESSION_TYPE`/`WAYLAND_DISPLAY`/`DISPLAY`, not from which binaries exist, so it fails silently. `yazi.toml` sidesteps this by piping `chafa` into the preview pane via the `piper` plugin instead of forcing yazi's own chafa adapter (which would require blinding yazi to the graphical session, and every child process — `xdg-open`, `wl-copy` — would inherit that).

### Neovim / LazyVim (`nvim/`)
`~/.config/nvim` is a symlink into this repo, so `lazy-lock.json` is a tracked file that changes on every `:Lazy update` — commit it, that lockfile is what makes another machine reproducible. Plugins (`~/.local/share/nvim/lazy`) and mason tools are *not* tracked; `install.sh` rebuilds both.

Four things that are easy to get wrong:
- LazyVim's language extras declare their DAP block with `optional = true`, so it stays inert until `dap.core` is enabled. Enabling `dap.core` retroactively activates debugging for Python and Java without touching those extras.
- Neovim gives `.github/workflows/*.yml` the plain `yaml` filetype, not `yaml.github`. actionlint is therefore registered under `yaml` and restricted by path with nvim-lint's `condition`.
- mason is declared with `cmd = "Mason"` only, so `:MasonInstall` does not exist in a headless run until the plugin is loaded explicitly.
- The `lang.scala` extra binds nvim-metals to filetypes `scala`, `sbt` *and* `java`, which collides with jdtls from `lang.java`. `lua/plugins/scala.lua` replaces the extra's `config` to restrict the autocmd to Scala — `ft` cannot be narrowed from an override, since lazy.nvim concatenates `ft`/`event`/`cmd`/`keys` across specs instead of replacing them. That same extra maps `<leader>me` to telescope, which is not installed (LazyVim uses snacks.picker).

`yamllint/config` lives under `nvim/` because nvim-lint is what invokes yamllint; a project-level `.yamllint` still wins over it.

### PDF generation stack (`pdfgithub/`)
`generate-pdf.sh` requires: `pandoc`, `xelatex` (TeX Live), `mermaid-cli` (`mmdc`), and `chromium`. The Puppeteer config is read from `/etc/mermaid-puppeteer.json` or `/etc/puppeteer-config.json`; the script generates a fallback in `/tmp/` if neither exists. Use named colors only in LaTeX — hex values break `xcolor`.

## Shell scripts

Scripts use `set -euo pipefail`. Keep that pattern when adding new scripts.

## Adding new tool configs

There is no enforced install convention — some tools have an `install.sh` (symlink-based), others are placed manually. When adding a new tool, create a subdirectory named after the tool and add the config files there. An `install.sh` is optional.

## Language / locale

Zed's LSP spell-checking (`ltex`) is configured for **Spanish** (`es`). This is intentional.
