#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/tmux_runtime.sh
source "$script_dir/../lib/tmux_runtime.sh"

current_info="$(tmux display-message "${tmux_current_target[@]}" -p '#{session_id}	#{session_name}')"
current_id="${current_info%%$'\t'*}"
current_name="${current_info#*$'\t'}"

if [[ -z "$current_id" || -z "$current_name" ]]; then
  echo "tmuxclean: failed to detect current session" >&2
  exit 1
fi

label="$current_name"
if [[ "$label" =~ ^[0-9]+__(.*)$ ]]; then
  label="${BASH_REMATCH[1]}"
elif [[ "$label" =~ ^[0-9]+[:_-](.*)$ ]]; then
  label="${BASH_REMATCH[1]}"
elif [[ "$label" =~ ^[0-9]+$ ]]; then
  label="main"
fi

label="${label//:/-}"
label="${label//__/-}"
[[ -n "$label" ]] || label="main"
new_name="1__${label}"

cleanup_suspend() {
  tmux set-option -gu @session_manager_suspended >/dev/null 2>&1 || true
}
trap cleanup_suspend EXIT

tmux set-option -gq @session_manager_suspended 1

while IFS= read -r session_id; do
  [[ -n "$session_id" ]] || continue
  [[ "$session_id" == "$current_id" ]] && continue
  tmux kill-session -t "$session_id" >/dev/null 2>&1 || true
done < <(tmux list-sessions -F '#{session_id}')

tmux rename-session -t "$current_id" "$new_name"
tmux switch-client -t "$current_id" >/dev/null 2>&1 || true

echo "tmuxclean: kept $new_name"
