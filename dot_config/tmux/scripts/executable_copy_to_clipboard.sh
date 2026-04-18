#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/tmux_runtime.sh
source "$script_dir/lib/tmux_runtime.sh"

# Routes tmux/vim copy to the right clipboard backend.
# Defaults:
#   - 默认优先系统剪贴板，失败时 OSC52。
#   - 强制 OSC52：TMUX_CLIPBOARD_FORCE_OSC52=1。
#
# Note: We strip trailing newlines so a later paste won't accidentally "press Enter".

content=$(tr -d '\r')
while [[ "$content" == *$'\n' ]]; do
  content="${content%$'\n'}"
done

have() {
  command -v "$1" >/dev/null 2>&1
}

is_writable_tty() {
  [[ -n "${1:-}" && "$1" != "not a tty" && -w "$1" ]]
}


resolve_tty() {
  local cand

  if is_writable_tty "${TTY:-}"; then
    printf '%s' "$TTY"
    return
  fi

  cand=$(tty 2>/dev/null || true)
  if is_writable_tty "$cand"; then
    printf '%s' "$cand"
    return
  fi

  if have tmux; then
    if [[ -n "${TMUX_PANE:-}" ]]; then
      cand=$(tmux display-message -p -t "${TMUX_PANE}" '#{pane_tty}' 2>/dev/null || true)
      if is_writable_tty "$cand"; then
        printf '%s' "$cand"
        return
      fi
    fi

    cand=$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)
    if is_writable_tty "$cand"; then
      printf '%s' "$cand"
      return
    fi

    cand=$(tmux list-clients -F '#{client_tty}' 2>/dev/null | head -n 1 || true)
    if is_writable_tty "$cand"; then
      printf '%s' "$cand"
      return
    fi
  fi
}

# Keep tmux buffer in sync (and trigger set-clipboard if enabled)
copy_via_tmux() {
  if have tmux && [[ -n "${TMUX:-}" ]]; then
    if tmux set-buffer -w -- "$content" 2>/dev/null || tmux set-buffer -- "$content"; then
      return 0
    fi
  fi
  return 1
}

# Platform clip helpers (local sessions)
copy_via_host() {
  if have pbcopy; then
    if printf '%s' "$content" | env LANG="${LANG:-en_US.UTF-8}" LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}" pbcopy; then
      return 0
    fi
  fi
  if have wl-copy; then
    if printf '%s' "$content" | wl-copy --type text 2>/dev/null || printf '%s' "$content" | wl-copy 2>/dev/null; then
      return 0
    fi
  fi
  if have xclip; then
    if printf '%s' "$content" | xclip -selection clipboard 2>/dev/null; then
      return 0
    fi
  fi
  if have xsel; then
    if printf '%s' "$content" | xsel --clipboard --input 2>/dev/null; then
      return 0
    fi
  fi
  if have powershell.exe; then
    if powershell.exe -NoProfile -Command Set-Clipboard -Value @"
${content}
"@; then
      return 0
    fi
  fi
  return 1
}

# OSC52 fallback (works over SSH to local terminal if allowed)
copy_via_osc52() {
  local max_bytes=${OSC52_MAX_BYTES:-100000}
  if (( max_bytes > 0 )) && (( ${#content} > max_bytes )); then
    return 1
  fi

  local base64
  base64=$(printf '%s' "$content" | base64 | tr -d '\r\n')
  local osc="\e]52;c;${base64}\a"

  # Wrap when inside tmux so the outer terminal receives the sequence
  if [[ -n "${TMUX:-}" ]]; then
    osc="\ePtmux;\e${osc}\e\\"
  fi

  local tty_target
  tty_target=$(resolve_tty || true)
  if [[ -n "$tty_target" && -w "$tty_target" ]]; then
    printf '%b' "$osc" > "$tty_target"
  else
    printf '%b' "$osc"
  fi
}

copy_via_tmux || true

force_osc52=${TMUX_CLIPBOARD_FORCE_OSC52:-0}

prefer_osc52=0
# Over SSH (e.g., iPad clients), prefer OSC52 so clipboard reaches the client device.
# Keep manual override via TMUX_CLIPBOARD_FORCE_OSC52=1.
if [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_TTY:-}" ]]; then
  prefer_osc52=1
fi
# When tmux server env doesn't carry SSH vars, inspect attached client tty via who(1).
if [[ $prefer_osc52 -eq 0 ]] && have tmux; then
  client_tty=$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)
  if [[ -n "$client_tty" ]]; then
    short_tty="${client_tty#/dev/}"
    if who | awk -v t="$short_tty" '$2==t && $0 ~ /\(.*\)$/ {found=1} END{exit found?0:1}'; then
      prefer_osc52=1
    fi
  fi
fi
if [[ "$force_osc52" == "1" ]]; then
  prefer_osc52=1
fi

if [[ $prefer_osc52 -eq 1 ]]; then
  copy_via_osc52 || copy_via_host || true
else
  copy_via_host || copy_via_osc52 || true
fi

exit 0
