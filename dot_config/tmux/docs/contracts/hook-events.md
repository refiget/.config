# Hook Events Contract

This document freezes the current hook/event behavior so refactors preserve semantics.

## Design rule

The refactor must preserve:
- the same tmux hook set
- the same top-level trigger mode (`run-shell` vs `run -b`)
- the same per-event child action order
- the same best-effort/error-tolerant behavior

For actions originally started with `run -b`, the dispatcher preserves **launch order**, not child-process completion order.

## Event table

| Source | Trigger mode | Dispatcher event | Arguments | Ordered child steps |
| --- | --- | --- | --- | --- |
| `01_general.conf` `pane-focus-in` | `run -b` | `pane-focus-in` | none | 1) update pane MRU 2) `refresh-client -S` |
| `02_hooks.conf` `client-attached` | `run -b` | `client-attached` | `#{client_tty}` | 1) session created sync 2) auto iPad mode attached |
| `02_hooks.conf` `client-detached` | `run -b` | `client-detached` | `#{client_tty}` | 1) auto iPad mode detached |
| `02_hooks.conf` `after-select-window` | `run-shell` | `after-select-window` | `#{pane_current_path}` | 1) run activation hook lookup |
| `02_hooks.conf` `session-created` | `run -b` | `session-created` | none | 1) session created sync 2) `refresh-client -S` |
| `02_hooks.conf` `session-renamed` | `run -b` | `session-renamed` | none | 1) `refresh-client -S` |
| `02_hooks.conf` `session-closed` | `run -b` | `session-closed` | none | 1) session created sync 2) `refresh-client -S` |
| config source-time bootstrap | `run-shell` | `bootstrap-sync` | none | 1) session created sync |
| source-time attached-session check | `run-shell` | `bootstrap-sync` | none | 1) session created sync |

## Notes

### `pane-focus-in` is a combined semantic event
Historically it was split across two conf files:
- MRU update in `conf.d/01_general.conf`
- refresh in `conf.d/02_hooks.conf`

The dispatcher combines them into one internal event while preserving the same launch order.

### `bootstrap-sync` intentionally may run twice
When tmux config is sourced while a session is already attached, the historical behavior runs `session_created.sh` twice:
1. unconditional source-time run
2. `if-shell -F '#{session_attached}' ...`

The refactor keeps this behavior for compatibility.

### Error handling
The dispatcher and event scripts should remain best-effort:
- do not abort the whole event if one child action fails
- do not add new user-visible messages by default
