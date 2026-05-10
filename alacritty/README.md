# alacritty config

Personal `alacritty.toml` tuned to run **Claude Code TUI inside tmux** on
Arch Linux + Wayland. Designed as a sibling of `../tmux/tmux.conf`: the
two files declare matching capabilities (truecolor, OSC 52 clipboard, OSC 8
hyperlinks, focus events, extended keys) so escape sequences flow end-to-end
between Claude Code → zsh → tmux → Alacritty without losing colors or
modifier keys.

## What it enables

- 24-bit truecolor — Claude Code diffs and minted listings render with the
  correct palette
- JetBrainsMono Nerd Font Mono at 11 pt with built-in box drawing for
  flush table borders in TUI apps
- Scrollback handed off to tmux (tmux keeps 100k lines; Alacritty keeps a
  10k-line local fallback for raw shells)
- `TERM=alacritty` forced via `[env]` so launches from `.desktop` files
  pick up the right terminfo
- `live_config_reload = true` — saving this file rereads it instantly
- Clipboard via `Ctrl+Shift+C` / `Ctrl+Shift+V`; `save_to_clipboard = true`
  so selections are mirrored to PRIMARY and CLIPBOARD
- Font-size hot keys (`Ctrl +/-/0`, plus numpad) for screen-share moments
- Vi-mode toggle (`Ctrl+Shift+Space`) and search (`Ctrl+Shift+F` / `B`)
- Stanford-cardinal accents (`#8C1515`) on the bell and vi cursor — match
  the Beamer Frankfurt+Stanford palette used in `presentations/`

## Install (any Arch box)

```bash
git clone git@github.com:cardel/cardel.git ~/repositorios/cardel
mkdir -p ~/.config/alacritty
ln -sfn ~/repositorios/cardel/alacritty/alacritty.toml ~/.config/alacritty/alacritty.toml
```

`live_config_reload = true` means the next save of this file is picked up
automatically; no restart needed.

## Requirements

- `alacritty >= 0.13` (TOML schema; YAML is rejected)
- `ttf-jetbrains-mono-nerd` — Arch package providing the configured family
- `wl-clipboard` *or* `xclip` — only needed for the tmux `y` keybind in
  copy mode; OSC 52 works without either
- A Wayland or X11 session — the file makes no compositor-specific calls

## Pairing with tmux

Use `../tmux/tmux.conf` alongside this file. The tmux side declares
Alacritty-specific terminal features:

```tmux
set -as terminal-features ",alacritty:RGB:usstyle:clipboard:hyperlinks:title:focus:extkeys:sixel"
```

That entry expects `TERM=alacritty` outside tmux, which is exactly what
`[env].TERM` here guarantees. Mismatched values silently disable
truecolor and OSC 52, so keep both files in sync if you fork either.

## tmux on launch (default)

The bottom of `alacritty.toml` has an active `[terminal.shell]` block
that attaches to (or creates) a tmux session named `main` on launch.

Trade-off: `tmux detach` closes the Alacritty window because the shell
process exits with the session. If you want the window to survive
detach, comment that block out and move the launcher to `~/.zshrc`:

```zsh
if [[ -z "$TMUX" ]] && [[ -n "$PS1" ]] && command -v tmux >/dev/null; then
  tmux attach -t main 2>/dev/null || tmux new -s main
fi
```

A bare `zsh` underneath then survives the detach and you can re-attach
without losing the window.
