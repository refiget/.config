# Status Interface Contract

The public status entrypoint remains:
- `tmux-status/right.sh`

Internal implementation may be split into helpers, but the external behavior is preserved.

## Stable output model

The right status is rendered as a single tmux status string with this segment order:

1. session segment
2. rainbarf / metrics segment
3. time segment
4. date segment

## Stable compatibility points

The refactor preserves:
- `tmux-status/right.sh` path
- session-name parsing rules for canonical and legacy names
- width fallback order:
  1. `#{client_width}`
  2. `#{window_width}`
  3. `COLUMNS`
- whole-right cutoff via `TMUX_RIGHT_MIN_WIDTH`
- session-pill cutoff via `TMUX_SESSION_RIGHT_MIN_WIDTH`
- session label truncation via `TMUX_SESSION_RIGHT_MAXLEN`
- `TMUX_SESSION_ICONS` parsing
- `TMUX_RAINBARF` / `TMUX_RAINBARF_*` behavior
- `@cpu_ema` as the smoothing state key
- graceful degradation when `rainbarf` is missing

## Internal split targets

`tmux-status/right.sh` may delegate to:
- `tmux-status/lib/runtime.sh`
- `tmux-status/lib/metrics.sh`
- `tmux-status/lib/segments.sh`

## Regression checklist

After changes, verify at least:
- narrow terminal hides the whole right status
- medium terminal hides only session pill when below its width threshold
- canonical name like `3__work` shows mapped icon + `work`
- legacy name like `3-work` still parses
- long session labels are truncated the same way
- missing `rainbarf` removes only that segment
- `@cpu_ema` continues to update
