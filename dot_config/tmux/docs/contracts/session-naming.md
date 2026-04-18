# Session Naming Contract

The session subsystem uses a canonical naming scheme managed by `scripts/session_manager.py`.

## Canonical write format

`<index>__<label>`

Examples:
- `1__main`
- `2__work`
- `3__notes`

## Backward-compatible read formats

The parser continues to accept legacy inputs for migration/compatibility:
- `<index>_<label>`
- `<index>-<label>`
- `<index>:<label>`
- `<index>` (label defaults)
- plain unindexed names (treated as labels until normalized)

## Label rules

Implemented by `sanitize_label()` and `cleanup_label()` in `scripts/session_manager.py`.

### `sanitize_label()`
- trims leading/trailing whitespace
- empty labels become the default label (`new`)
- replaces `:` with `-`
- replaces `__` with `-`

### `cleanup_label(index, label)`
- sanitizes the label
- strips repeated leading `<index><separator>` prefixes caused by older naming bugs
- falls back to the default label when cleanup empties the label

## Consumers of this contract

### Authoritative writer
- `scripts/session_manager.py`

### Readers
- `scripts/session_manager.py`
- `tmux-status/right.sh` and its internal helpers

## Stability rule

This contract is intentionally stable across the refactor:
- canonical output format stays `<index>__<label>`
- backward-compatible reads stay enabled
- the status renderer continues to derive icon/display behavior from the numeric prefix
