# tmux

This directory contains the tmux configuration.

- Loader: `~/dotfiles/.tmux.conf` → deployed to `~/.tmux.conf`
- Modular configs: `conf.d/*.conf`
- Scripts: `scripts/`
- Status scripts: `tmux-status/`

## Architecture docs

- Overview: `ARCHITECTURE.md`
- Contracts:
  - `docs/contracts/hook-events.md`
  - `docs/contracts/session-naming.md`
  - `docs/contracts/tmux-state.md`
  - `docs/contracts/status-interface.md`

## Notes on script layout

The repo now uses canonical subsystem-owned script paths under:
- `scripts/hooks/`
- `scripts/session/`
- `scripts/pane/`
- `scripts/window/`
- `scripts/status/`
- `scripts/lib/`

Older root-level script paths are retained as compatibility wrappers so existing tmux config and external calls do not break.

For an overview, see the repo-level **README-tmux.md**.
