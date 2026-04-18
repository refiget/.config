# tmux State Contract

This document records tmux option/environment state used internally by this repo.

## tmux user options

| Key | Owner | Readers | Classification | Notes |
| --- | --- | --- | --- | --- |
| `@mru_pane_ids` | `scripts/pane/fzf_panes.tmux` | pane/fzf helpers | internal | pane MRU cache |
| `@cpu_ema` | `tmux-status/right.sh` / `tmux-status/lib/metrics.sh` | status renderer | internal | CPU smoothing cache |
| `@theme_color` | `scripts/status/update_theme_color.sh` | status/window style config | internal | derived active theme color |
| `@session_manager_suspended` | session cleanup flows | session lifecycle scripts | internal | prevents re-entrant clean behavior |
| `@tab_*` | `conf.d/08_toggle_theme.conf` | status/window rendering | repo-public config | style knobs consumed by theme/status |
| `@status_fg` | `conf.d/08_toggle_theme.conf` | status renderer | repo-public config | status palette input |
| `@time_fg`, `@time_bg` | `conf.d/08_toggle_theme.conf` | status renderer | repo-public config | time segment colors |
| `@date_fg`, `@date_bg` | `conf.d/08_toggle_theme.conf` | status renderer | repo-public config | date segment colors |
| `@session_label_fg`, `@session_label_bg` | `conf.d/08_toggle_theme.conf` | status renderer | repo-public config | session pill colors |

## tmux environment knobs

| Key | Source | Classification | Notes |
| --- | --- | --- | --- |
| `TMUX_THEME_COLOR` | user/session/global env | repo-public config | base theme color input |
| `TMUX_MODE` | user/session/global env | repo-public config | mode-aware color selection |
| `TMUX_THEME_PRESET` | user/session/global env | repo-public config | preset selection |
| `TMUX_SESSION_ICONS` | `conf.d/08_toggle_theme.conf` | repo-public config | comma-separated session icon mapping |
| `TMUX_RAINBARF` and `TMUX_RAINBARF_*` | `conf.d/08_toggle_theme.conf` | repo-public config | right-status metrics behavior |
| `TMUX_RIGHT_MIN_WIDTH` | env | repo-public config | whole right-status cutoff |
| `TMUX_SESSION_RIGHT_MIN_WIDTH` | env | repo-public config | session-pill cutoff |
| `TMUX_SESSION_RIGHT_MAXLEN` | env | repo-public config | session label truncation |

## tmux runtime selection

Shell and Python helpers use the same server-selection priority:

1. `TMUX_SOCKET_NAME` → `tmux -L <name>`
2. `TMUX_SOCKET_PATH` → `tmux -S <path>`
3. fallback to plain `tmux`

## Stability rule

The refactor preserves all keys above. Internal keys remain implementation details, but their names do not change during this migration.
