#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [RESULT_DIR]" >&2
  exit 2
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
host_mros2_wasm_dir=${HOST_MROS2_WASM_DIR:-"$repo_dir/mros2-wasm"}
pi_host=${PI_HOST:-ubuntu@192.168.100.3}
pi_repo=${PI_REPO:-/home/ubuntu/experiment-20260718}
trial_id=$(date +%Y%m%dT%H%M%S)
run_dir=${1:-"$repo_dir/results/cloud-$trial_id"}
host_run_dir="$run_dir/host"
pi_run_dir="$pi_repo/results/cloud-$trial_id-pi"

iwasm="$host_mros2_wasm_dir/third_party/wamr/product-mini/platforms/linux/build/iwasm"
wasm="$host_mros2_wasm_dir/cmake_build/occupancy_grid_node.wasm"

if [ ! -x "$iwasm" ] || [ ! -f "$wasm" ]; then
  echo "ERROR: host iwasm or occupancy_grid_node.wasm is missing." >&2
  echo "Set HOST_MROS2_WASM_DIR to the built mros2-wasm directory." >&2
  exit 1
fi

mkdir -p "$host_run_dir"
host_system_pid=''
host_process_pid=''
iwasm_pid=''

stop_pid() {
  local pid=${1:-}
  [ -n "$pid" ] || return 0
  kill -TERM "$pid" 2>/dev/null || return 0
  for _ in $(seq 1 5); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 1
  done
  kill -KILL "$pid" 2>/dev/null || true
}

cleanup() {
  stop_pid "$host_process_pid"
  stop_pid "$host_system_pid"
  stop_pid "$iwasm_pid"
}
trap cleanup EXIT INT TERM

# WAMR/WASI cannot truncate output files created by a previous run.
rm -f /tmp/mROS2-data.txt /tmp/occupancy_grid_node_health.txt \
  /tmp/occupancy_grid_node_metrics.csv

"$repo_dir/scripts/collect_system_metrics.sh" \
  "$host_run_dir/system_metrics.csv" >"$host_run_dir/system_metrics.stderr" 2>&1 &
host_system_pid=$!

"$iwasm" \
  --max-threads=128 \
  --addr-pool=0.0.0.0/0:7400-9000 \
  --heap-size=52428800 \
  --dir=/tmp \
  "$wasm" >"$host_run_dir/iwasm.log" 2>&1 &
iwasm_pid=$!

for _ in $(seq 1 30); do
  if grep -q 'ready to pub/sub message' "$host_run_dir/iwasm.log"; then
    break
  fi
  sleep 1
done
grep -q 'ready to pub/sub message' "$host_run_dir/iwasm.log"

"$repo_dir/scripts/collect_process_metrics.sh" \
  "$host_run_dir/process_metrics.csv" "iwasm:$iwasm_pid" \
  >"$host_run_dir/process_metrics.stderr" 2>&1 &
host_process_pid=$!

printf '=== HOST_WASM_READY run_dir=%s ===\n' "$run_dir"
printf 'Pi power measurement starts when POWER_MEASUREMENT_START appears below.\n'

ssh "$pi_host" "mkdir -p '$pi_run_dir'"
ssh "$pi_host" \
  "cd '$pi_repo' && ./scripts/run_wasm_offline_measurement.sh --external-wasm '$pi_run_dir'"

mkdir -p "$run_dir/pi"
scp -r "$pi_host:$pi_run_dir/." "$run_dir/pi/"

cp /tmp/occupancy_grid_node_metrics.csv "$host_run_dir/"
cp /tmp/occupancy_grid_node_health.txt "$host_run_dir/"
cp /tmp/mROS2-data.txt "$host_run_dir/"
"$repo_dir/scripts/summarize_latency.sh" \
  "$host_run_dir/occupancy_grid_node_metrics.csv" \
  > "$host_run_dir/latency_summary.csv"

{
  printf 'trial_id=%s\n' "$trial_id"
  printf 'pi_host=%s\n' "$pi_host"
  printf 'pi_repo=%s\n' "$pi_repo"
  printf 'host_mros2_wasm_dir=%s\n' "$host_mros2_wasm_dir"
  git -C "$repo_dir" rev-parse HEAD | sed 's/^/experiment_commit=/'
  git -C "$host_mros2_wasm_dir" rev-parse HEAD | sed 's/^/mros2_wasm_commit=/'
} > "$run_dir/metadata.txt"

printf '=== CLOUD_MEASUREMENT_COMPLETE results=%s ===\n' "$run_dir"
