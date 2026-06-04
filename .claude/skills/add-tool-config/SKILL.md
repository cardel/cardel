---
name: add-tool-config
description: Add a new tool's configuration to this dotfiles repo, following the established layout and conventions.
---

When the user wants to add a new tool's configuration to this dotfiles repo, follow these steps:

1. **Identify the tool** — ask the user which tool they want to add and what its config file(s) are called (e.g., `~/.config/foo/config.toml`).

2. **Create the directory** — create a subdirectory at the repo root named after the tool (lowercase, no spaces). Example: `.claude/skills/` → use the tool name.

3. **Add the config file(s)** — create the config file(s) inside the subdirectory. If the user provides existing content, use it verbatim. Otherwise, generate a sensible starting config.

4. **Optional install.sh** — ask if they want a symlink-based `install.sh`. If yes, write one following the pattern in `alacritty/install.sh` or `tmux/install.sh`:
   - Detect XDG_CONFIG_HOME (default `~/.config`)
   - Create target directory if needed
   - Symlink each config file with `ln -sf`
   - Print a success message

5. **Font / dependency check** — if the tool uses fonts or has runtime dependencies, note them in a comment at the top of the config file.

6. **Remind the user** — if `yazi/` or any directory was recently untracked, remind them to `git add` the new directory.

Respect existing conventions:
- TOML files: 2-space indentation
- Bash scripts: `set -euo pipefail` at the top, color-coded logging optional
- No build system; no package.json or Cargo.toml needed
