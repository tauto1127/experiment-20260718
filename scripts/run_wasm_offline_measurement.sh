#!/usr/bin/env bash
set -eo pipefail

external_wasm=false
if [ "${1:-}" = "--external-wasm" ]; then
  external_wasm=true
  shift
fi
if [ "$#" -gt 1 ]; then
  echo "usage: $0 [--external-wasm] [RESULT_DIR]" >&2
  exit 2
fi

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
run_dir=${1:-"$repo_dir/results/run-$(date +%Y%m%dT%H%M%S)"}
mkdir -p "$run_dir"

source /opt/ros/humble/setup.bash
set -u
"$repo_dir/setup_network.sh"

iwasm="$repo_dir/mros2-wasm/third_party/wamr/product-mini/platforms/linux/build/iwasm"
wasm="$repo_dir/mros2-wasm/cmake_build/occupancy_grid_node.wasm"
bag="$repo_dir/turtlebot3_simulation_bag"
launch="$repo_dir/cartographer_no_occupancy.launch.py"

wasm_sudo_pid=''
wasm_pid=''
carto_launch_pid=''
carto_pid=''
bag_pid=''
monitor_pid=''
system_monitor_pid=''

stop_pid() {
  local pid=${1:-}
  [ -n "$pid" ] || return 0
  sudo kill -TERM "$pid" 2>/dev/null || return 0
  for _ in $(seq 1 5); do
    sudo kill -0 "$pid" 2>/dev/null || return 0
    sleep 1
  done
  sudo kill -KILL "$pid" 2>/dev/null || true
}

cleanup() {
  for pid in "$monitor_pid" "$system_monitor_pid" "$bag_pid" "$carto_pid" "$carto_launch_pid" "$wasm_pid" "$wasm_sudo_pid"; do
    stop_pid "$pid"
  done
}
trap cleanup EXIT INT TERM

if [ "$external_wasm" = false ]; then
  # WAMR/WASI cannot truncate a file that was created by an earlier run in this
  # environment.  Start every trial with fresh, exact output targets.
  sudo rm -f /tmp/mROS2-data.txt /tmp/occupancy_grid_node_health.txt \
    /tmp/occupancy_grid_node_metrics.csv

  sudo -E "$iwasm" \
    --max-threads=128 \
    --addr-pool=0.0.0.0/0:7400-9000 \
    --heap-size=52428800 \
    --dir=/tmp \
    "$wasm" >"$run_dir/iwasm.log" 2>&1 &
  wasm_sudo_pid=$!

  for _ in $(seq 1 30); do
    if grep -q 'ready to pub/sub message' "$run_dir/iwasm.log"; then
      break
    fi
    sleep 1
  done
  grep -q 'ready to pub/sub message' "$run_dir/iwasm.log"
  wasm_pid=$(pgrep -P "$wasm_sudo_pid" | head -n 1)
else
  printf '=== EXTERNAL_WASM_READY waiting_for_cartographer ===\n' \
    | tee -a "$run_dir/measurement_markers.log"
fi

ros2 launch "$launch" use_sim_time:=true >"$run_dir/cartographer.log" 2>&1 &
carto_launch_pid=$!
carto_pid=''
for _ in $(seq 1 50); do
  carto_pid=$(pgrep -P "$carto_launch_pid" | head -n 1 || true)
  [ -n "$carto_pid" ] && break
  sleep 0.1
done
[ -n "$carto_pid" ]
power_measurement_started_at=$(date --iso-8601=seconds)
printf '=== POWER_MEASUREMENT_START cartographer_launch=%s pid=%s ===\n' \
  "$power_measurement_started_at" "$carto_pid" | tee -a "$run_dir/measurement_markers.log"
printf '%s\n' "$power_measurement_started_at" > "$run_dir/power_measurement_start.txt"
sleep 5

bash -lc "source /opt/ros/humble/setup.bash && exec ros2 bag play '$bag' --clock" \
  >"$run_dir/rosbag.log" 2>&1 &
bag_pid=$!

process_targets=("cartographer:$carto_pid" "rosbag:$bag_pid")
if [ "$external_wasm" = false ]; then
  process_targets=("iwasm:$wasm_pid" "${process_targets[@]}")
fi
"$repo_dir/scripts/collect_process_metrics.sh" "$run_dir/process_metrics.csv" \
  "${process_targets[@]}" &
monitor_pid=$!
"$repo_dir/scripts/collect_system_metrics.sh" "$run_dir/system_metrics.csv" &
system_monitor_pid=$!

wait "$bag_pid" || true
stop_pid "$monitor_pid"
wait "$monitor_pid" 2>/dev/null || true
monitor_pid=''
stop_pid "$system_monitor_pid"
wait "$system_monitor_pid" 2>/dev/null || true
system_monitor_pid=''
stop_pid "$carto_pid"
stop_pid "$carto_launch_pid"
stop_pid "$wasm_pid"
stop_pid "$wasm_sudo_pid"

power_measurement_ended_at=$(date --iso-8601=seconds)
printf '=== POWER_MEASUREMENT_END rosbag_complete=%s ===\n' \
  "$power_measurement_ended_at" | tee -a "$run_dir/measurement_markers.log"

if [ "$external_wasm" = false ]; then
  cp /tmp/occupancy_grid_node_metrics.csv "$run_dir/occupancy_grid_node_metrics.csv"
  cp /tmp/occupancy_grid_node_health.txt "$run_dir/occupancy_grid_node_health.txt"
  cp /tmp/mROS2-data.txt "$run_dir/mROS2-data.txt"
  "$repo_dir/scripts/summarize_latency.sh" "$run_dir/occupancy_grid_node_metrics.csv" \
    > "$run_dir/latency_summary.csv"
fi

git -C "$repo_dir" rev-parse HEAD > "$run_dir/experiment_commit.txt"
git -C "$repo_dir/mros2-wasm" rev-parse HEAD > "$run_dir/mros2_wasm_commit.txt"
git -C "$repo_dir/mros2-wasm/workspace/occupancy_grid_node" rev-parse HEAD \
  > "$run_dir/occupancy_grid_node_commit.txt"
