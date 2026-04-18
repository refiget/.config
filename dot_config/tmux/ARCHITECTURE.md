# tmux Architecture

This tmux repo is structured as a layered system rather than a single `.tmux.conf` dump.

## Loading model

The external loader (`~/.tmux.conf`) sources this repo, and `conf.d/*.conf` acts as the composition root.

Load order is significant:

1. `00_bootstrap.conf` — earliest bootstrap toggles
2. `01_general.conf` — runtime defaults, environment propagation, focus hooks
3. `02_hooks.conf` — lifecycle/event hooks
4. `03_prefix_display.conf` — prefix and UI basics
5. `04_navigation.conf` — window/session navigation
6. `05_clipboard.conf` — copy/paste bridge
7. `06_pane_navigation.conf` — pane/window movement
8. `07_copy_mode.conf` — copy-mode UX
9. `08_toggle_theme.conf` — theme/status assembly
10. `09_session_switch.conf` — indexed session switching
11. `10_terminal.conf` — terminal/OSC52/RGB/cursor compatibility

## Subsystems

### Assembly layer
- `conf.d/*.conf`
- Owns tmux option setup, bind registration, and hook registration.

### Hook/event layer
- `scripts/hooks/dispatch.sh`
- `scripts/hooks/events/*.sh`
- Owns the mapping from tmux hook triggers to repo actions.

### Session subsystem
- Canonical command adapters: `scripts/session/*.sh`
- Domain core: `scripts/session_manager.py`
- Responsibilities: session naming, normalization, switching, moving, cleanup.

### Pane subsystem
- Canonical pane tools: `scripts/pane/*`
- Includes `scripts/pane/fzf_panes.tmux`, layout/orientation helpers, and pane-title helpers.

### Window subsystem
- Canonical window tools: `scripts/window/*`
- Owns window reorder/move helpers.

### Status/theme subsystem
- Canonical theme/status scripts: `scripts/status/*`
- Public status entrypoint: `tmux-status/right.sh`
- Internal status helpers: `tmux-status/lib/*`

### Integration/runtime helpers
- `scripts/lib/tmux_runtime.sh`
- Clipboard helpers and platform integrations remain under `scripts/` when they are not worth further splitting.

## Canonical paths vs compatibility paths

This repo now distinguishes between:

- **canonical implementation paths**: the new subsystem-owned files under `scripts/session/`, `scripts/pane/`, `scripts/window/`, `scripts/status/`, `scripts/hooks/`, `scripts/lib/`
- **compatibility paths**: older root-level script paths retained as thin wrappers so existing tmux config and external calls keep working

Examples:
- `fzf_panes.tmux` → compatibility wrapper for `scripts/pane/fzf_panes.tmux`
- `scripts/new_session.sh` → compatibility wrapper for `scripts/session/new_session.sh`
- `scripts/toggle_orientation.sh` → compatibility wrapper for `scripts/pane/toggle_orientation.sh`
- `scripts/update_theme_color.sh` → compatibility wrapper for `scripts/status/update_theme_color.sh`

## Public entrypoints kept stable

The following are treated as stable repo entrypoints and remain valid after the refactor:

- `fzf_panes.tmux`
- `tmux-status/right.sh`
- `tmux-status/left.sh`
- `scripts/new_session.sh`
- `scripts/session_created.sh`
- `scripts/switch_session_by_index.sh`
- `scripts/rename_session_prompt.sh`
- `scripts/move_session.sh`
- `scripts/move_window_to_session.sh`
- `scripts/tmux_clean.sh`
- `scripts/toggle_orientation.sh`
- `scripts/swap_window_wrap.sh`
- `scripts/update_theme_color.sh`

## Internal tmux state

These tmux options are treated as internal repo state. Their keys are intentionally preserved for compatibility, but they are not documented as external extension points:

- `@mru_pane_ids`
- `@cpu_ema`
- `@theme_color`
- `@session_manager_suspended`

See `docs/contracts/` for the authoritative contract notes.
