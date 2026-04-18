#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/tmux_runtime.sh
source "$script_dir/../lib/tmux_runtime.sh"

# fzf_panes.tmux
# - Maintains an MRU list of pane IDs in @mru_pane_ids (updated via pane-focus-in hook)
# - Opens an fzf UI in a new window to select panes and perform actions
#
# Interface (must remain stable):
#   bash fzf_panes.tmux new_window
#   bash fzf_panes.tmux update_mru_pane_ids
#   bash fzf_panes.tmux do_action
#   bash fzf_panes.tmux panes_src

have() { command -v "$1" >/dev/null 2>&1; }

tmux_opt() {
  tmux show -gqv "$1" 2>/dev/null || true
}

tmux_set_opt() {
  tmux set -g "$1" "$2" >/dev/null 2>&1 || true
}

# Read @mru_pane_ids into an array (space-separated list)
read_mru_ids() {
  local raw
  raw=$(tmux_opt '@mru_pane_ids')
  if [[ -z "${raw:-}" ]]; then
    return 0
  fi
  # Split on whitespace; pane ids never contain whitespace.
  # shellcheck disable=SC2206
  MRU_IDS=( $raw )
}

write_mru_ids() {
  local -a ids=("$@")
  tmux_set_opt '@mru_pane_ids' "${ids[*]}"
}

new_window() {
  have fzf || return 0

  local pane_id
  pane_id=$(tmux_opt '@fzf_pane_id')
  if [[ -n "${pane_id:-}" ]]; then
    tmux kill-pane -t "$pane_id" >/dev/null 2>&1 || true
  fi

  # Run the action UI in a dedicated new window.
  tmux new-window "bash \"$0\" do_action" >/dev/null 2>&1 || true
}

# Invoked by pane-focus-in event.
update_mru_pane_ids() {
  local current
  current=$(tmux display-message -p '#D')

  local -a old_ids
  local -a new_ids
  MRU_IDS=()
  read_mru_ids
  old_ids=("${MRU_IDS[@]:-}")

  new_ids=("$current")
  local id
  for id in "${old_ids[@]:-}"; do
    [[ -n "${id:-}" ]] || continue
    [[ "$id" == "$current" ]] && continue
    new_ids+=("$id")
  done

  write_mru_ids "${new_ids[@]}"
}

do_action() {
  trap 'tmux set -gu @fzf_pane_id >/dev/null 2>&1 || true' EXIT SIGINT SIGTERM

  local current_pane_id
  current_pane_id=$(tmux display-message -p '#D')
  tmux_set_opt '@fzf_pane_id' "$current_pane_id"

  local cmd
  cmd="bash \"$0\" panes_src"

  local shell_tmux
  shell_tmux=$(tmux_shell_prefix)

  # fzf preview (show last N lines of the target pane)
  local preview_cmd
  preview_cmd=$(cat <<EOF
start=\$(( \$(${shell_tmux} display-message -t {1} -p "#{pane_height}") - ${FZF_PREVIEW_LINES:-20} ));
(( start>0 )) && echo "\$start" || echo 0
EOF
)
  preview_cmd="${shell_tmux} capture-pane -pe -S \$(${preview_cmd}) -t {1}"

  # Most recent pane (first in @mru_pane_ids)
  local last_pane_cmd="\$(${shell_tmux} show -gqv \"@mru_pane_ids\" | cut -d\\  -f1)"

  local selected
  selected=$(FZF_DEFAULT_COMMAND="$cmd" \
    fzf -m \
      --preview="$preview_cmd" \
      --preview-window='down:80%' \
      --reverse \
      --info=inline \
      --header-lines=1 \
      --delimiter='\s{2,}' \
      --with-nth=2..-1 \
      --nth=1,2,9 \
      --bind="alt-p:toggle-preview" \
      --bind="ctrl-r:reload($cmd)" \
      --bind="ctrl-x:execute-silent(${shell_tmux} kill-pane -t {1})+reload($cmd)" \
      --bind="ctrl-v:execute(${shell_tmux} move-pane -h -t $last_pane_cmd -s {1})+accept" \
      --bind="ctrl-s:execute(${shell_tmux} move-pane -v -t $last_pane_cmd -s {1})+accept" \
      --bind="ctrl-t:execute-silent(${shell_tmux} swap-pane -t $last_pane_cmd -s {1})+reload($cmd)" \
  ) || return 0

  [[ -n "${selected:-}" ]] || return 0

  # Build selected pane id set
  local -A sel
  local line pane_id
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    pane_id=${line%%[[:space:]]*}
    [[ -n "${pane_id:-}" ]] && sel["$pane_id"]=1
  done <<< "$selected"

  # Preserve MRU ordering among selected ids
  local -a ids_o
  local -a ids
  MRU_IDS=()
  read_mru_ids
  ids_o=("${MRU_IDS[@]:-}")

  local id
  for id in "${ids_o[@]:-}"; do
    [[ -n "${id:-}" ]] || continue
    if [[ -n "${sel[$id]:-}" ]]; then
      ids+=("$id")
    fi
  done

  local id_n=${#ids[@]}
  (( id_n > 0 )) || return 0

  local id1=${ids[0]}
  if (( id_n == 1 )); then
    tmux switch-client -t"$id1" >/dev/null 2>&1 || true
    return 0
  fi

  # Multiple panes: break the first pane into its own window, then move others into it.
  tmux break-pane -s"$id1" >/dev/null 2>&1 || true

  local i
  for (( i=1; i<id_n; i++ )); do
    tmux move-pane -t"${ids[i-1]}" -s"${ids[i]}" >/dev/null 2>&1 || true
    tmux select-layout -t"$id1" 'tiled' >/dev/null 2>&1 || true
  done

  # Preserve original behavior: choose a 2-pane layout based on window aspect ratio.
  local layout='tiled'
  if (( id_n == 2 )); then
    local w_wid w_hei
    w_wid=$(tmux display-message -t"$id1" -p '#{window_width}' 2>/dev/null || tmux display-message -p '#{window_width}' 2>/dev/null || echo 0)
    w_hei=$(tmux display-message -t"$id1" -p '#{window_height}' 2>/dev/null || tmux display-message -p '#{window_height}' 2>/dev/null || echo 0)
    if [[ "$w_wid" =~ ^[0-9]+$ && "$w_hei" =~ ^[0-9]+$ && "$w_hei" -gt 0 ]]; then
      if (( 9*w_wid > 16*w_hei )); then
        layout='even-horizontal'
      else
        layout='even-vertical'
      fi
    fi
  fi

  tmux switch-client -t"$id1" >/dev/null 2>&1 || true
  tmux select-layout -t"$id1" "$layout" >/dev/null 2>&1 || true
}

panes_src() {
  printf "%-6s  %-7s  %5s  %8s  %4s  %4s  %5s  %-8s  %-7s  %s\n" \
    'PANEID' 'SESSION' 'PANE' 'PID' '%CPU' '%MEM' 'THCNT' 'TIME' 'TTY' 'CMD'

  local panes_info
  panes_info=$(tmux list-panes -aF '#D #{=|6|…:session_name} #I.#P #{pane_tty} #T' 2>/dev/null || true)
  [[ -n "${panes_info:-}" ]] || exit 0

  # Exclude the fzf UI pane itself
  panes_info=$(printf '%s\n' "$panes_info" | sed -E "/^${TMUX_PANE:-}
? /d")

  # Build tty list for ps
  local ttys
  ttys=$(awk '{printf("%s,", $4)}' <<<"$panes_info" | sed 's/,$//')
  [[ -n "${ttys:-}" ]] || exit 0

  # Keep only processes that own the TTY (+)
  local ps_info
  ps_info=$(ps -t"$ttys" -o stat,pid,pcpu,pmem,thcount,time,tname,cmd 2>/dev/null | awk '$1~/\+/ {$1="";print $0}' || true)

  local hostname
  hostname=$(hostname 2>/dev/null || echo '')

  # Read pane entries into arrays for stable lookup
  local -a pane_lines
  mapfile -t pane_lines <<<"$panes_info"

  local -a mru
  MRU_IDS=(); read_mru_ids
  mru=("${MRU_IDS[@]:-}")

  local -a ids_out
  local id line pane_id session pane tty title
  for id in "${mru[@]:-}"; do
    [[ -n "${id:-}" ]] || continue

    for line in "${pane_lines[@]:-}"; do
      [[ -n "$line" ]] || continue

      # pane line: "<id> <session> <pane> <tty> <title...>"
      # shellcheck disable=SC2206
      local parts=( $line )
      pane_id=${parts[0]:-}
      [[ "$pane_id" == "$id" ]] || continue

      ids_out+=("$id")
      session=${parts[1]:-}
      pane=${parts[2]:-}
      tty=${parts[3]:-}
      tty=${tty#/dev/}
      title=${parts[*]:4}

      # Find matching ps line by tty name (tname column)
      local ps_line
      while IFS= read -r ps_line; do
        [[ -n "$ps_line" ]] || continue
        # shellcheck disable=SC2206
        local p_info=( $ps_line )
        [[ "${p_info[5]:-}" == "$tty" ]] || continue

        printf "%-6s  %-7s  %5s  %8s  %4s  %4s  %5s  %-8s  %-7s  " \
          "$pane_id" "$session" "$pane" "${p_info[@]::6}"

        local cmd
        cmd=${p_info[*]:6}

        # If vim set the title to the current file, append it (original behavior)
        if [[ "$cmd" =~ ^n?vim && -n "${title:-}" && "$title" != "$hostname" ]]; then
          # shellcheck disable=SC2206
          local cmd_arr=( $cmd )
          cmd="${cmd_arr[0]} $title"
        fi

        printf '%s\n' "$cmd"
        break
      done <<<"$ps_info"

      break
    done
  done

  # Keep MRU list clean (only panes we actually saw)
  write_mru_ids "${ids_out[@]}"
}

cmd="${1:-}"
shift || true
case "$cmd" in
  new_window) new_window "$@" ;;
  update_mru_pane_ids) update_mru_pane_ids "$@" ;;
  do_action) do_action "$@" ;;
  panes_src) panes_src "$@" ;;
  *)
    # Backwards compat: allow calling as "$0 <func>"
    "$cmd" "$@" 2>/dev/null || true
    ;;
esac
