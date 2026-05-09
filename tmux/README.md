# tmux config

Personal `tmux.conf` tuned for Claude Code TUI on Alacritty + zsh
(Arch Linux). Tested with tmux 3.6, alacritty 0.17, JetBrainsMono Nerd Font.

## What it enables

- 24-bit truecolor (`RGB`) so Claude Code diffs render with the right palette
- Undercurl / colored underline (`usstyle`) for LSP-style hints
- OSC 52 system clipboard (`set-clipboard on`) — yank works without `xclip`
- OSC 8 clickable hyperlinks in tool output
- Focus events (`focus-events on`) so editors and TUIs see focus changes
- Extended-keys (`extended-keys on` + `extkeys`) for Ctrl+Shift+Arrow etc.
- Mouse on, generous scrollback (100k lines), 10 ms ESC time
- vim-style pane navigation (`prefix h/j/k/l`) and intuitive splits
  (`prefix |` vertical, `prefix -` horizontal)

## Install (any machine)

```bash
git clone git@github.com:cardel/cardel.git ~/repositorios/cardel
ln -sfn ~/repositorios/cardel/tmux/tmux.conf ~/.tmux.conf
```

Reload from inside tmux: `prefix r` (or `tmux source-file ~/.tmux.conf`).

## Requirements

- `tmux >= 3.4` (uses the `terminal-features` syntax introduced there)
- `wl-clipboard` *or* `xclip` (only needed for the `y` keybind in copy
  mode; OSC 52 works without either)
- A truecolor-capable terminal — Alacritty, foot, kitty, WezTerm, recent
  xterm. The `terminal-features` lines explicitly cover Alacritty and
  `xterm-256color`.

## Notes for Alacritty users

Alacritty 0.17 already does the right things by default
(`TERM=alacritty`, truecolor, OSC 52). No mandatory config changes.
Optional tweaks live in `../alacritty/` if you want a portable Alacritty
config alongside this tmux config.
