#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_CSV" >&2
  exit 2
fi

output_csv=$1
interval_sec=${METRICS_INTERVAL_SEC:-1}

mkdir -p "$(dirname "$output_csv")"
printf 'epoch_ms,cpu_percent,mem_total_kb,mem_available_kb,mem_used_kb,mem_used_percent,swap_total_kb,swap_free_kb\n' > "$output_csv"

read_cpu_ticks() {
  # total is every CPU state; idle includes iowait to report non-idle system load.
  awk '/^cpu / { total=0; for (i=2; i<=NF; ++i) total+=$i; print total, $5+$6; exit }' /proc/stat
}

previous_total=''
previous_idle=''

while :; do
  now_ms=$(date +%s%3N)
  read -r total_ticks idle_ticks < <(read_cpu_ticks)

  cpu_percent=0
  if [ -n "$previous_total" ]; then
    delta_total=$((total_ticks - previous_total))
    delta_idle=$((idle_ticks - previous_idle))
    if [ "$delta_total" -gt 0 ]; then
      cpu_percent=$(awk -v total="$delta_total" -v idle="$delta_idle" \
        'BEGIN { printf "%.2f", 100 * (total - idle) / total }')
    fi
  fi

  mem_total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  mem_available_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  swap_total_kb=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
  swap_free_kb=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)
  mem_used_kb=$((mem_total_kb - mem_available_kb))
  mem_used_percent=$(awk -v used="$mem_used_kb" -v total="$mem_total_kb" \
    'BEGIN { printf "%.2f", 100 * used / total }')

  printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$now_ms" "$cpu_percent" "$mem_total_kb" "$mem_available_kb" "$mem_used_kb" \
    "$mem_used_percent" "$swap_total_kb" "$swap_free_kb" >> "$output_csv"

  previous_total=$total_ticks
  previous_idle=$idle_ticks
  sleep "$interval_sec"
done
