# Status Interface Contract

The public status entrypoint remains:
- `tmux-status/right.sh`

Internal implementation may be split into helpers, but the external behavior is preserved.

## Stable output model

The right status is rendered as a single tmux status string with this segment order:

1. session segment
2. optional Things segment
3. time segment

Date segment has been removed in favor of minimalism.

## Design notes

- All segments are backgroundless (`bg=default`) to blend into the terminal.
- Session segment uses italic text; color shifts via `@pane_flag_fg` when multiple panes are present.
- Things segment uses bold+italic yellow (`#f9e2af`) as the visual anchor.
- Time segment uses low-contrast italic gray (`#9399b2`).

## Stable compatibility points

The refactor preserves:
- `tmux-status/right.sh` path
- session-name parsing rules for canonical and legacy names
- width fallback order:
  1. `#{client_width}`
  2. `#{window_width}`
  3. `COLUMNS`
- whole-right cutoff via `TMUX_RIGHT_MIN_WIDTH`
- session segment cutoff via `TMUX_SESSION_RIGHT_MIN_WIDTH`
- session label truncation via `TMUX_SESSION_RIGHT_MAXLEN`
- `TMUX_SESSION_ICONS` parsing
- optional `TMUX_THINGS` / `TMUX_THINGS_*` segment gating and refresh timing
- graceful degradation when Things AppleScript refresh fails

## Internal split targets

`tmux-status/right.sh` may delegate to:
- `tmux-status/lib/runtime.sh`
- `tmux-status/lib/segments.sh`
- `tmux-status/lib/things.sh`

## Regression checklist

After changes, verify at least:
- narrow terminal hides the whole right status
- medium terminal hides only session segment when below its width threshold
- canonical name like `3__work` shows mapped icon + `work`
- legacy name like `3-work` still parses
- long session labels are truncated the same way
- Things cache refreshes no more than once per 60s by default
- empty Today cache renders `ALL DONE`
- multi-pane windows shift session segment foreground to `@pane_flag_fg`
