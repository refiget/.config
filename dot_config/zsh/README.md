# zsh

This directory contains the modular zsh configuration.

- Loader: `~/dotfiles/.zshrc` → deployed to `~/.zshrc`
- Startup flow: `.zshenv` (always) → `.zprofile` (login) → `.zshrc` (interactive loader)
- Modules: `conf.d/*.conf`

## Layout rules

- `.zshrc` is a thin loader only
- `01_*` = shell basics that must load first
- `02_*` = PATH / environment wiring
- `10_*` = framework / prompt
- `20_*` = aliases and command ergonomics
- `30_*` = tool integrations and shell helpers
- `40_*` = UI / keybindings / behavior fixes
- `50_*` = language-specific helpers
- `80_*` = early machine-local hooks
- `90_*` = checks
- `95_*` = autostart / exec boundaries
- `99_*` = final machine-local overrides
- prefer keeping tool-specific setup out of the loader
- prefer `path=( ... $path )` over repeated raw `export PATH=...:$PATH`

## Local hooks

- `~/.zshrc.pre.local` runs from `80_local_overrides.conf`
  - use it for variables that later modules need to read, e.g.:
    - `export ZSH_SKIP_DEP_CHECKS=1`
    - `export ZSH_SKIP_TMUX_AUTOSTART=1`
- `~/.zshrc.local` runs from `99_local_overrides.conf` as the final compatibility hook
- Note: `95_autostart_tmux.conf` may `exec tmux`, so `~/.zshrc.local` only runs when startup continues past tmux autostart

For an overview, see the repo-level **README-zsh.md**.

## Current structure

- `10_framework_zim.conf` → Zim framework init
- `11_prompt.conf` → Pure prompt styling
- `20_aliases_core.conf` → safe/default aliases
- `21_aliases_workflow.conf` → personal workflow shortcuts / repo-local helper wrappers
- `30_openclaw.conf` → OpenClaw completion
- `33_tools_navigation.conf` → yazi / zoxide / fzf (single-provider init)
- `34_tools_runtime.conf` → lazy nvm
- `35_tools_history.conf` → atuin + Ctrl-R backend detection
- `40_keybindings.conf` → vi mode and final keybinding policy
- `50_python_venv.conf` → Python virtualenv helpers
- `80_local_overrides.conf` → early hook for `~/.zshrc.pre.local`
- `90_dep_checks.conf` → soft startup checks (honors `ZSH_SKIP_DEP_CHECKS`)
- `95_autostart_tmux.conf` → optional tmux auto-entry (honors `ZSH_SKIP_TMUX_AUTOSTART`)
- `99_local_overrides.conf` → final hook for `~/.zshrc.local`
