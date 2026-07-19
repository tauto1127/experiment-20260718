#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 occupancy_grid_node_metrics.csv" >&2
  exit 2
fi

awk -F, '
  NR == 1 { next }
  $2 == "submap_list_received" { received[$3] = $1 }
  $2 == "submap_query_complete" {
    if (!first_query[$3]) first_query[$3] = $1
    last_query[$3] = $1
  }
  $2 == "occupancy_grid_generated" { grid[$3] = $1 }
  $2 == "map_file_write_complete" && received[$3] && !emitted[$3] {
    emitted[$3] = 1
    first_q = first_query[$3] ? first_query[$3] - received[$3] : ""
    last_q = last_query[$3] ? last_query[$3] - received[$3] : ""
    grid_ms = grid[$3] ? grid[$3] - received[$3] : ""
    write_ms = $1 - received[$3]
    print $3 "," first_q "," last_q "," grid_ms "," write_ms
  }
' "$1" | {
  printf 'submap_list_seq,first_query_complete_ms,last_query_complete_ms,occupancy_grid_generated_ms,map_file_write_complete_ms\n'
  cat
}
