#!/usr/bin/env bash
set -euo pipefail

# Render a 10-slot bar using solid/empty blocks
render_bar() {
  local pct=${1%.*}
  ((pct < 0)) && pct=0
  ((pct > 100)) && pct=100

  local slots=10
  local filled=$(((pct * slots + 50) / 100))
  local empty=$((slots - filled))

  local bar=""
  if ((filled > 0)); then
    bar+=$(printf '█%.0s' $(seq 1 "$filled"))
  fi
  if ((empty > 0)); then
    bar+=$(printf '░%.0s' $(seq 1 "$empty"))
  fi

  printf '%s %s%%' "$bar" "$pct"
}

# CPU percentage normalized by core count
cpu_pct() {
  local cores total_usage max_usage
  cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
  total_usage=$(ps -A -o %cpu= | awk '{s+=$1} END {printf "%.0f", s}')
  max_usage=$((cores * 100))
  if ((max_usage == 0)); then
    echo 0
    return
  fi
  echo $(((total_usage * 100) / max_usage))
}

# Memory percentage (macOS) approximating Activity Monitor "Memory Used"
# used ~= active + speculative + wired + compressed, all from vm_stat
mem_pct() {
  local page_size total_bytes used_bytes

  # vm_stat output contains: "page size of 16384 bytes" (Apple Silicon often 16K)
  page_size=$(vm_stat | awk '/page size of/ {print $8; exit}' | tr -d '.')

  total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  if (( total_bytes == 0 )); then
    echo 0
    return
  fi

  used_bytes=$(vm_stat | awk -v ps="${page_size:-4096}" '
    function n(line){ gsub(/[^0-9]/,"",line); return line+0 }
    /Pages active/ {a=n($0)}
    /Pages speculative/ {s=n($0)}
    /Pages wired down/ {w=n($0)}
    /Pages occupied by compressor/ {c=n($0)}
    END { printf "%.0f", (a+s+w+c)*ps }
  ')

  awk -v used="$used_bytes" -v total="$total_bytes" 'BEGIN {printf "%.0f", (used/total)*100}'
}

cpu_val=$(cpu_pct)
mem_val=$(mem_pct)

printf 'CPU %s | MEM %s\n' "$(render_bar "$cpu_val")" "$(render_bar "$mem_val")"

