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
