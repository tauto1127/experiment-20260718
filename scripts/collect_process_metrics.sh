#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 OUTPUT_CSV NAME:PID [NAME:PID ...]" >&2
  exit 2
fi

output_csv=$1
shift
interval_sec=${METRICS_INTERVAL_SEC:-1}
clock_ticks=$(getconf CLK_TCK)

mkdir -p "$(dirname "$output_csv")"
printf 'epoch_ms,name,pid,cpu_percent,rss_kb,vmhwm_kb,threads\n' > "$output_csv"

declare -A previous_ticks previous_ms

while :; do
  alive=0
  now_ms=$(date +%s%3N)

  for target in "$@"; do
    name=${target%%:*}
    pid=${target#*:}
    stat_file="/proc/$pid/stat"
    status_file="/proc/$pid/status"
    [ -r "$stat_file" ] || continue
    [ -r "$status_file" ] || continue
    alive=1

    cpu_ticks=$(awk '{print $14 + $15}' "$stat_file")
    rss_kb=$(awk '/^VmRSS:/ {print $2}' "$status_file")
    hwm_kb=$(awk '/^VmHWM:/ {print $2}' "$status_file")
    threads=$(awk '/^Threads:/ {print $2}' "$status_file")
    cpu_percent=0

    if [ -n "${previous_ticks[$pid]:-}" ]; then
      elapsed_ms=$((now_ms - previous_ms[$pid]))
      delta_ticks=$((cpu_ticks - previous_ticks[$pid]))
      if [ "$elapsed_ms" -gt 0 ]; then
        cpu_percent=$(awk -v ticks="$delta_ticks" -v hz="$clock_ticks" -v ms="$elapsed_ms" \
          'BEGIN { printf "%.2f", 100 * ticks * 1000 / hz / ms }')
      fi
    fi

    printf '%s,%s,%s,%s,%s,%s,%s\n' \
      "$now_ms" "$name" "$pid" "$cpu_percent" "${rss_kb:-0}" "${hwm_kb:-0}" "${threads:-0}" \
      >> "$output_csv"
    previous_ticks[$pid]=$cpu_ticks
    previous_ms[$pid]=$now_ms
  done

  [ "$alive" -eq 1 ] || break
  sleep "$interval_sec"
done
