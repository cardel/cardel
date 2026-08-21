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
| `obs/` | OBS Studio — virtual camera (v4l2loopback) for sharing the webcam |

`yazi/` is tracked in the repo.

## Installed configs may be copies, not symlinks — check first

`./install.sh` with no arguments prints, for every tool, whether its live path is
a **symlink**, a **copy**, or **absent**. Run it before reasoning about any config
in this repo.

This matters because the two machines are not wired the same way. On the desktop
`~/.config/nvim` is a symlink; on the laptop (`carlos-portatil`) several configs
were plain copies that had silently drifted for months. Reading a file here and
assuming it is what runs is how you end up debugging the wrong text — it happened
four times in one session: `hypr/overrides.conf` (live copy was 130 lines behind),
`nvim/` (four plugin files missing), `.zshrc` and `xdg/mimeapps.list` (both
diverged in *both* directions).

Still copies today, each because merging needs a decision rather than a link:

| Config | Why it is not linked yet |
|---|---|
| `hypr/` | the active monitor block in `overrides.conf` is the desktop's (`DP-3`), and the laptop's live file sources `touchpad.conf`, which the repo version dropped |
| `.zshrc` | other installers append to it (Google Cloud SDK, filen-cli); the plugin lists differ and only the repo side has `export TERMINAL=alacritty` |
| `xdg/` | live has `drracket`/`mpv`/`evisions-launch`, repo has `inode/directory=yazi.desktop` and others |

## Claude's own configuration is not here

The global instructions — the ones that apply in every session and every
repository — live in the private workspace repo, `cardel/claude-work`, under
`claude/`, and `~/.claude/CLAUDE.md` is a symlink to that file. They are kept
out of this repository on purpose: this one is the public profile repo.

## graft does not apply here

The global instruction is "graft first, always". **This repo is the exception**, and
it is not a matter of the index being stale — graft cannot parse anything here.

Measured with `@nanonets/graft@0.10.1` (the latest published version) on a copy of
this repo: `wiring: 0 nodes, 0 edges, 0 cards — parsed: 0 of 0 files`. The graph
comes out empty and `INDEX.md` is 10 lines of boilerplate.

The reason is graft's language registry. Its depth tier covers ts/tsx/js/jsx/py/go/java
(`dist/graph/extract.js`) and its breadth tier adds rust, c, cpp, ruby, php, c#,
kotlin, scala, swift, elixir, solidity, ocaml, zig and dart (`GENERIC_LANGS` in
`dist/graph/generic.js`). Neither tier has a row for **Lua or Bash**, which is all
the code this repo contains — 12 `.lua` and 6 `.sh`, plus TOML, JSON and Markdown.
The `tree-sitter-lua.wasm` and `tree-sitter-bash.wasm` grammars do ship inside the
package, so supporting them upstream is one registry row plus a `queries/<name>.scm`;
until that lands there is nothing to index.

`~/repositorios/work/scripts/bootstrap-graft.sh` reaches the same conclusion on its
own: its `UMBRAL` counts files matching a code-extension list that excludes `.lua`
and `.sh`, so it scores this repo at 0 and skips it.

So: navigate this repo with `grep`, `Read` and the file tree. Do not wire `.mcp.json`
here and do not query graft for it — an empty graph answers "not found" for code that
does exist, which is worse than not asking.

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

**PDFs preview as text, not as an image**, via `pdftotext`. Rendering the page
and passing it through chafa produced something unreadable, and that is
arithmetic rather than a misconfiguration: a Letter page at 150 dpi is
1275×1650 px and the pane is roughly 60×39 cells — a 20× downscale, at which a
paragraph is a grey smear. There is no way around it either, because **Alacritty
0.17 still implements no graphics protocol** (verified: no sixel or kitty string
in the binary, the man page or the changelog). `pdftotext -layout` gives the
title, authors and abstract, which is what actually identifies a file in a list;
`fold -s -w "${w}"` wraps instead of truncating, since pdftotext emits up to 70
columns.

For real images, chafa must be told the terminal's **cell shape** or previews
come out stretched. It assumes 1:2; JetBrainsMono Nerd Font Mono is
600/1320 = 0.4545 (advance 600, line height = ascent 1020 + descent 300 +
lineGap 0). Measured on a Letter page (true aspect 0.7727), the default painted
it at 0.6992 — 9.5% too narrow, i.e. stretched vertically. `--font-ratio
600/1320` brings it to 0.7575. **Recompute this if the terminal font ever
changes.** Colour needs no flag: chafa still emits truecolor through piper's
pipe even though it cannot interrogate the terminal.

Requires `chafa` and `poppler` (`pdftoppm`). Alacritty implements no graphics protocol, and the adapter yazi picks on its own (`Wayland`) delegates to `ueberzugpp` — `Adapter::matches` decides from `XDG_SESSION_TYPE`/`WAYLAND_DISPLAY`/`DISPLAY`, not from which binaries exist, so it fails silently. `yazi.toml` sidesteps this by piping `chafa` into the preview pane via the `piper` plugin instead of forcing yazi's own chafa adapter (which would require blinding yazi to the graphical session, and every child process — `xdg-open`, `wl-copy` — would inherit that).

### Neovim / LazyVim (`nvim/`)
`~/.config/nvim` is a symlink into this repo, so `lazy-lock.json` is a tracked file that changes on every `:Lazy update` — commit it, that lockfile is what makes another machine reproducible. Plugins (`~/.local/share/nvim/lazy`) and mason tools are *not* tracked; `install.sh` rebuilds both.

Five things that are easy to get wrong:
- LazyVim's language extras declare their DAP block with `optional = true`, so it stays inert until `dap.core` is enabled. Enabling `dap.core` retroactively activates debugging for Python and Java without touching those extras.
- Neovim gives `.github/workflows/*.yml` the plain `yaml` filetype, not `yaml.github`. actionlint is therefore registered under `yaml` and restricted by path with nvim-lint's `condition`.
- mason is declared with `cmd = "Mason"` only, so `:MasonInstall` does not exist in a headless run until the plugin is loaded explicitly.
- On a clean machine the first Neovim start **destroys `lazy-lock.json`**. LazyVim's spec is imported from the LazyVim plugin itself, so lazy.nvim installs in several rounds, and every round ends in `Lock.update()`, which empties the in-memory lock table and rewrites it from what is on disk. Later rounds find no lock entry and check out branch HEAD instead. Measured: 25 of 60 plugins pinned correctly, 35 on HEAD, lockfile rewritten and self-consistent, so nothing errors. `install.sh` copies the lockfile aside, restores it after the bootstrap and runs `:Lazy! restore`; passing `lockfile = true` to the lua API does not help, because the damage happens before any `-c` runs.
- The `lang.scala` extra binds nvim-metals to filetypes `scala`, `sbt` *and* `java`, which collides with jdtls from `lang.java`. `lua/plugins/scala.lua` replaces the extra's `config` to restrict the autocmd to Scala — `ft` cannot be narrowed from an override, since lazy.nvim concatenates `ft`/`event`/`cmd`/`keys` across specs instead of replacing them. That same extra maps `<leader>me` to telescope, which is not installed (LazyVim uses snacks.picker).

`yamllint/config` lives under `nvim/` because nvim-lint is what invokes yamllint; a project-level `.yamllint` still wins over it.

Language-server traps found by measurement, each one silent:

- **jdtls needs Java 21+ to *run*.** mason's launcher (`bin/jdtls.py`,
  `get_java_executable`) reads `JAVA_HOME` then `java` on PATH and aborts with
  `requires at least Java 21`. The system default here is 17, so it died every
  time. `java.lua` passes `--java-executable` instead of touching anything
  global — changing the default with `archlinux-java` or exporting `JAVA_HOME`
  would also change what Gradle, Maven and students' terminal builds use. Note
  this is a *different* setting from `configuration.runtimes`, which picks the
  JDK projects are **analysed against**. `java-8-openjdk` is excluded from that
  list: it ships no `javac` here, and jdtls drops a JDK-less runtime silently.
- **Parameter-name inlay hints are on by default** and read as syntax that is
  not in the file — `printf(format: "%d", x)`, `calcular(base: x, tasa: y)`.
  Turned off per-server (clangd flags, jdtls `parameterNames = "none"`) rather
  than via `inlay_hints.exclude`, because that list is *replaced* on merge, so
  two files in `lua/plugins/` setting it would race and the last one
  alphabetically would win.
- **Metals is not in mason** — 590 packages, none for metals/scala/bloop. So it
  cannot go in `ensure_installed`; `scala.lua` triggers nvim-metals' own
  coursier download on the first Scala buffer. Gradle works out of the box:
  nvim-metals' default `root_patterns` include `settings.gradle` but *not*
  `build.gradle`, so the project root wins over the module. Bloop names the
  build target after the Gradle subproject (`app` here), never `root`.
- **texlab ships chktex disabled** and the `lang.tex` extra only sets `keys`,
  so 544 `.tex` files had zero diagnostics while `chktex` sat in `/usr/bin`.
- **Copilot's channel is chosen by `vim.g.ai_cmp`** (LazyVim default `true`),
  and it must be set in `lua/config/options.lua` — LazyVim loads that file
  *before* sourcing plugin modules (`lazyvim/config/init.lua:329`), which is
  when the extras read it. `true` mixes Copilot into the same list as the LSP
  methods and turns on ghost text; `false` moves it to its own inline channel.
  Either way the suggestion length cannot be capped — copilot.lua exposes no
  such option — so the answer is `accept_word` / `accept_line`, which exist but
  are unmapped by the extra. Do **not** bind `accept_line` to `<M-CR>`:
  copilot.lua validates suggestion, nes and panel keymaps in one pass
  (`keymaps/init.lua:170`) and the panel's default `open` is `<M-CR>`, so it
  errors `Duplicate keymap detected` on every start — `panel = { enabled =
  false }` does not spare you, since `validate()` never checks `enabled`.
- **nvim-cmp does not open on a bare LSP trigger character.** With jdtls
  attached, `import java.util.` yields nothing — verified at 2, 5, 10, 15 and
  25 seconds — while `<C-Space>` returns 50 entries instantly and typing one
  more letter (`.c`) opens it normally. Forcing `cmp.complete()` from a
  `TextChangedI` autocmd fixes the dot but breaks the next keystroke: the
  entries get filtered locally instead of re-queried, so `.c` drops to
  snippets only. **Unsolved**; blink.cmp handles trigger characters natively
  and the spec for it is already in `completion.lua` behind `optional = true`.


### Verifying a Neovim change — the methods that actually work

Every wrong conclusion in this repo's history came from a bad measurement, not
from bad reasoning. These are the traps, each one found the hard way:

- **`nvim --headless` cannot test anything LSP-related.** LazyVim loads on
  `VeryLazy`, which fires after `UIEnter`, so no server ever attaches and every
  buffer looks clean. Wrap it in a pty:
  `script -qec "nvim file.java -c '...'" /dev/null`.
- **To drive keystrokes, use a socket, and always check what landed.**
  `nvim --listen /tmp/s` in the background, then `nvim --server /tmp/s
  --remote-send` / `--remote-expr` from outside. `nvim_input` through this path
  is intermittent — it silently mangled a buffer into `tttttttttass App {` in
  one run and did nothing at all in another. Assert on `getline(1)` and
  `mode()` before believing any result.
- **Read merged options with `LazyVim.opts("<plugin>")`.** Not
  `require("lazy.core.plugin").values(p, "opts", true)` — that third argument
  means *is_list*, and passing it returns something that looks plausible and is
  wrong (it reported `servers.clangd = nil` for a fully configured clangd).
- **nvim-cmp registers `nvim_lsp` on `InsertEnter`, per client.** Inspecting
  `cmp.core.sources` from normal mode shows the source missing, which reads
  exactly like a bug. It is not; `cmp_nvim_lsp.setup()` only installs the
  autocmd.
- **mason's binaries are not on the shell `PATH`.** `command -v shellcheck`
  returns nothing while nvim-lint runs it happily from
  `~/.local/share/nvim/mason/bin`. Check that directory, not the shell.
- **When measuring terminal art, do not filter blank lines.** A mostly-white
  page emits rows of spaces that strip to empty; dropping them turned a correct
  39-row measurement into 15 and inverted the conclusion.

The general rule: when a probe says something is broken, first prove the probe
can see something that is known to work.

### Sharing the webcam and mic between OBS, browsers and Zoom (`obs/`)

The camera **can** be shared, by more than two programs, and the first
conclusion here was wrong. What is exclusive is the *device node*, not the
camera:

- **`/dev/video0` is exclusive.** With one capture running, the second dies at
  `VIDIOC_REQBUFS returned -1 (Device or resource busy)`. The webcam's second
  node `/dev/video1` is no escape hatch — *Metadata Capture* only, no image.
- **PipeWire multiplexes video**, and already exposes the webcam as a
  `Video/Source` node with nothing installed. Measured on the desktop with
  **three** overlapping consumers (one `gst-launch` standing in for OBS plus two
  Chromium instances on separate profiles): all three `[active]` on
  `C922 Pro Stream Webcam:capture_1` at once, zero errors. During that same
  overlap, `fuser -v /dev/video0` showed **one** opener — `pipewire`. That is
  the whole mechanism, and it is why there is no limit of two.
- **The microphone was never the problem.** PipeWire opens the ALSA device once
  and mixes N clients, so OBS and Zoom capture it simultaneously with no setup.
  Measured on the Blue Yeti: two `pw-record` both `[active]` on
  `Blue Microphones:capture_FL`, both WAVs valid.

So there are two routes, and `obs/README.md` documents both. Route 1 (PipeWire:
OBS's `Video Capture Device (PipeWire)` source + the browser's
`enable-webrtc-pipewire-camera` flag) needs no root and no module, and Zoom sees
the raw camera. Route 2 (v4l2loopback) is what you want for teaching, because
Zoom then sees the composed OBS scene; `exclusive_caps=1` is the option Chromium
needs to list the loopback node, and that one is **still unverified** — the
module is installed on neither machine.

**The measurement trap:** the first two-consumer test showed both processes
getting all their frames and proved nothing — the first had already finished
before the second started. Overlap has to be confirmed in the graph
(`wpctl status`) *while* both run, which is the same rule as everywhere else in
this file: prove the probe can see the thing before believing it.

Route 1 is scripted in `obs/navegadores.sh`, which covers **every Chromium
derivative** (Chromium, Vivaldi, Chrome, Brave — same flag, same `Local State`
format, one function) plus Firefox, and is idempotent with `--off` to reverse.
Three things that bite:

- **The process name is not the command name.** Vivaldi runs as `vivaldi-bin`,
  so the `pgrep -x vivaldi` guard never fired: the script would write the flag
  and Vivaldi would erase it on exit, silently. Every browser row carries its
  exact process name for that reason.
- **Firefox's two browsers store the setting in completely different places.**
  Chromium's flag goes in `Local State` — the same file `chrome://flags` writes
  — while Firefox's `media.webrtc.camera.allow-pipewire` must go in `user.js`,
  **not** `prefs.js`, because Firefox rewrites `prefs.js` on exit and would drop
  it. `user.js` is reread at every start and wins, at the cost of pinning the
  value beyond `about:config`'s reach. Both browsers must be closed when the
  script runs, for the same reason.
- **Installed ≠ profiled.** No profile exists until the first launch; the
  desktop has `firefox` in `/usr/bin` and no `~/.mozilla` at all. The script
  says so in those words, because a bare "skipped" reads as "already fine".

Before writing, the script greps the installed binary for the flag string
(`grep -qa`, tenths of a second on 300 MB) so a future Chromium that drops or
renames it produces a warning instead of a dead `Local State` entry. Present in
Chromium 151 and Vivaldi 8.1. Note `/usr/bin/chromium` is a 14 KB wrapper — grep
`/usr/lib/chromium/chromium`, or the check silently finds nothing.

**Sharing the mic is free; picking the right one is not.** In the three-consumer
measurement both browsers captured `C922 Pro Stream Webcam:capture_FL` — the
webcam's built-in mic — while the Blue Yeti sat unused, because whatever does
not name a device gets the default and WirePlumber ranks the webcam mic higher.
Fixed once with `pactl set-default-source <name>`, persisted by WirePlumber in
`~/.local/state/wireplumber/default-nodes`. That only helps callers that ask for
the default: OBS names the device per audio source, and browsers remember the
choice **per site**, so a Zoom tab that already stored the webcam mic keeps it.
`comprobar.sh` lists the mics, marks the active one and warns when a webcam mic
wins over a standalone one.

`obs/comprobar.sh` reports the state of either route on any machine without
changing anything; nothing in it hardcodes `/dev/videoN` or node ids, since both
differ between the laptop and the desktop.

`obs/install.sh` **copies to `/etc` instead of symlinking**, the only installer
in the repo that does. A symlink from `/etc/modprobe.d` into a repo under `$HOME`
would put kernel module parameters within reach of anything running as the user,
and `/etc/modules-load.d` is read by systemd very early in boot. The root
`install.sh` grew a `FUENTES` table for this: copy-installed tools report
`copiado` / `COPIA DESFASADA` by comparing content, because for them "not a
symlink" is correct rather than a warning.

### ProtonVPN starts itself but must not connect itself (`hypr/`)

Two separate things, and confusing them costs an afternoon. `exec-once` only
*launches* the app; what connects is `connect_at_app_startup` in
`~/.config/Proton/VPN/app-config.json` (GUI: Settings → General → Auto connect,
where typing `OFF` writes `null`). It shipped as `"FASTEST"`, which is why the
VPN came up seconds after login.

The binary is `protonvpn-app`. There is no `proton-vpn` and no `protonvpn-cli` —
`proton-vpn-gtk-app` ships no CLI — and Hyprland's `exec-once` fails silently on
a missing command, so the laptop's live config had been launching nothing for
months. `--start-minimized` is safe here because waybar's `modules-left`
includes `tray`.

The app reads that JSON once at startup and rewrites it only when a setting is
changed in the GUI (`controller.py:372,384`), so editing the file under a
running app sticks — unless you then touch some other setting in that same
session, which flushes the stale in-memory `FASTEST` back to disk.

### gromit-mpx draws on the whole X screen, and its own keys never arrive (`hypr/`)

Two separate defects, both invisible until measured, both fixed from Hyprland's
side because gromit offers no lever for either.

- **Its hotkeys are grabbed on XWayland, not the compositor.** `--debug` prints
  `Grabbing hot key 'F9' from keyboard '3'`, and an XWayland grab only receives
  keys while an X window holds focus — which gromit's overlay never takes, by
  design, so clicks reach what is underneath. The same log line shows the MPX in
  the name does not survive either: `Now 1 enabled devices`, one virtual
  pointer instead of separate ones. So the actions are bound in
  `overrides.conf` and delivered over the CLI. A `flatpak run` with options
  costs 130 ms measured — fine for a keybinding.
- **There is no monitor option.** The binary accepts only `--active --clear
  --debug --key --keycode --line --opacity --quit --redo --reload --toggle
  --undo --undo-key --undo-keycode --version --visibility`. It paints the whole
  X screen, which under XWayland is the bounding box of every output (3840×1080
  here). Worse, where it lands depends on which monitor has focus at launch:
  measured opening at `at=[1920,0]` once and `at=[0,0]` another, always
  `size=[3840,1079]`. In the first case the canvas is offset by a full screen
  from the coordinates gromit believes it has.

Two traps in the fix itself:

- **`monitor` is required; `move` alone is not enough.** For a floating window
  Hyprland resolves `move` relative to whichever monitor it drops the window on.
  Verified by forcing focus onto HDMI-A-1: without the line gromit appeared at
  `at=[1920,0]`, with it at `at=[0,0]`.
- **The flat window-rule syntax is gone in 0.56.2.** `windowrule = float,
  class:^(Gromit-mpx)$` returns `invalid field float: missing a value`. Only the
  block form parses, which is what the rest of `overrides.conf` already uses.

Note the live file here is a **copy**, not a symlink (see the table above), so
editing the repo changes nothing until it is copied to
`~/.config/hypr/user_configs/overrides.conf` and `hyprctl reload` runs.

### PDF generation stack (`pdfgithub/`)
`generate-pdf.sh` requires: `pandoc`, `xelatex` (TeX Live), `mermaid-cli` (`mmdc`), and `chromium`. The Puppeteer config is read from `/etc/mermaid-puppeteer.json` or `/etc/puppeteer-config.json`; the script generates a fallback in `/tmp/` if neither exists. Use named colors only in LaTeX — hex values break `xcolor`.

## Shell scripts

Scripts use `set -euo pipefail`. Keep that pattern when adding new scripts.

## Adding new tool configs

Every tool lives in a subdirectory named after it and carries its own
`install.sh` that symlinks into place, backing up any existing real file first.
The root `install.sh` is only a front-end: it lists status, runs one by name, or
runs everything with `--all`.

When adding a tool, register it in the root script's three tables —
`INSTALADORES`, `DESTINOS`, and `MANUALES` if linking it would clobber something
another installer writes to (that is why `zsh` is excluded from `--all`).

Some tools configure themselves and never read anything through Neovim, so their
files are linked by `nvim/install.sh` into the path *they* look at:
`yamllint/config` → `~/.config/yamllint/config`, and `clangd/config.yaml` →
`~/.config/clangd/config.yaml`. The clangd one disables `UnusedIncludes` and
`MissingIncludes`, which without a `compile_commands.json` told students to
delete the `#include <stdio.h>` their `printf` needs. There are 1147 C/C++ files
across 45 CMake projects and 85 Makefiles here and **no compilation database at
all**; `CMAKE_EXPORT_COMPILE_COMMANDS=ON` in `.zshrc` covers the CMake half,
Makefiles need `bear -- make`.

## Language / locale

Zed's LSP spell-checking (`ltex`) is configured for **Spanish** (`es`). This is intentional.
