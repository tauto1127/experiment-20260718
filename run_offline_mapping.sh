#!/bin/bash
# Environment setup
source /opt/ros/humble/setup.bash

# Ensure network is configured
echo "Ensuring veth network interfaces are set up..."
/home/osslab/.gemini/antigravity-cli/brain/e19f3663-cbb5-4bb0-8ea9-8bce66f49925/scratch/setup_network.sh

# Cleanup trap for background processes
PLAY_PID=""
CARTO_PID=""
WASM_PID=""

cleanup() {
    echo "=== Shutting down offline mapping ==="
    if [ -n "$WASM_PID" ] && kill -0 "$WASM_PID" 2>/dev/null; then
        echo "Stopping mros2-wasm (PID $WASM_PID)..."
        kill -INT "$WASM_PID" 2>/dev/null || true
    fi
    if [ -n "$CARTO_PID" ] && kill -0 "$CARTO_PID" 2>/dev/null; then
        echo "Stopping Cartographer (PID $CARTO_PID)..."
        kill -INT "$CARTO_PID" 2>/dev/null || true
    fi
    if [ -n "$PLAY_PID" ] && kill -0 "$PLAY_PID" 2>/dev/null; then
        echo "Stopping rosbag play (PID $PLAY_PID)..."
        kill -INT "$PLAY_PID" 2>/dev/null || true
    fi
    echo "=== Teardown Complete ==="
}
trap cleanup EXIT

echo "Starting rosbag playback..."
# Play rosbag. Set ROS_LOCALHOST_ONLY=0 so it publishes to veth_host
export ROS_LOCALHOST_ONLY=0
ros2 bag play /home/osslab/turtlebot3_simulation_bag --clock > /tmp/rosbag_play.log 2>&1 &
PLAY_PID=$!

sleep 2

echo "Starting ROS 2 Cartographer..."
ros2 launch /home/osslab/ishimotti-mros2-posix/workspace/occupancy_grid_node/launch/cartographer_no_occupancy.launch.py use_sim_time:=true > /tmp/cartographer_offline.log 2>&1 &
CARTO_PID=$!

sleep 3

echo "Starting mros2-wasm-stable (occupancy_grid_node)..."
# Set environment variables for the WASM application
export MROS2_IFNAME=veth_wasm

# Execute WAMR using wamr-fast-interp-stable
/home/osslab/wamr-fast-interp-stable/product-mini/platforms/linux/build_cr/iwasm \
  --addr-pool=0.0.0.0/0:8000-9000 \
  --max-threads=128 \
  --env=MROS2_IFNAME=veth_wasm \
  --dir=/tmp \
  /home/osslab/mros2-wasm-stable/cmake_build/occupancy_grid_node.wasm > /tmp/mros2_wasm_offline.log 2>&1 &
WASM_PID=$!

echo "All components launched."
echo "  Rosbag Play PID: $PLAY_PID"
echo "  Cartographer PID: $CARTO_PID"
echo "  mros2-wasm PID:   $WASM_PID"
echo ""
echo "Monitoring logs. Press Ctrl+C to stop."
echo ""

# Monitor the WAMR wasm logs in real-time
tail -f /tmp/mros2_wasm_offline.log &
TAIL_PID=$!

# Wait for playback to finish or user interrupt
wait $PLAY_PID || true
kill $TAIL_PID 2>/dev/null || true
echo "Rosbag playback finished."
