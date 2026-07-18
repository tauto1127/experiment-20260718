#!/bin/bash
# Environment setup
export TURTLEBOT3_MODEL=burger
source /opt/ros/humble/setup.bash

# Variables
BAG_PID=""
GAZEBO_PID=""

# Cleanup function to be called on exit
cleanup() {
    echo "=== Cleaning Up Processes ==="
    if [ -n "$BAG_PID" ] && kill -0 "$BAG_PID" 2>/dev/null; then
        echo "Stopping rosbag record (PID $BAG_PID) gracefully..."
        kill -INT "$BAG_PID"
        # Wait up to 10 seconds for rosbag to write metadata
        for i in {1..10}; do
            if ! kill -0 "$BAG_PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        # Force kill if still running
        kill -9 "$BAG_PID" 2>/dev/null || true
    fi

    if [ -n "$GAZEBO_PID" ] && kill -0 "$GAZEBO_PID" 2>/dev/null; then
        echo "Stopping Gazebo simulation (PID $GAZEBO_PID) gracefully..."
        kill -INT "$GAZEBO_PID"
        # Wait up to 5 seconds
        for i in {1..5}; do
            if ! kill -0 "$GAZEBO_PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        kill -9 "$GAZEBO_PID" 2>/dev/null || true
    fi
    
    # Final cleanup of any dangling Gazebo servers
    killall gzserver 2>/dev/null || true
    echo "=== Teardown Complete ==="
}

# Set trap to ensure cleanup runs on exit (success, error, SIGINT, SIGTERM)
trap cleanup EXIT

# Cleanup previous recording if it exists
echo "Cleaning up previous bag directory..."
rm -rf /home/osslab/turtlebot3_simulation_bag

echo "Starting Headless Gazebo Simulation..."
ros2 launch /home/osslab/.gemini/antigravity-cli/brain/e19f3663-cbb5-4bb0-8ea9-8bce66f49925/scratch/turtlebot3_world_headless.launch.py > /tmp/gazebo_headless.log 2>&1 &
GAZEBO_PID=$!

# Wait for Gazebo server to spin up
echo "Waiting for Gazebo simulation to start (10 seconds)..."
sleep 10

echo "Starting Rosbag Recording..."
# Record to /home/osslab/turtlebot3_simulation_bag
ros2 bag record /scan /odom /tf /tf_static /imu /joint_states -o /home/osslab/turtlebot3_simulation_bag > /tmp/rosbag_record.log 2>&1 &
BAG_PID=$!

# Wait for recorder to initialize
sleep 3

echo "Starting automated robot movement (60 seconds)..."
python3 /home/osslab/.gemini/antigravity-cli/brain/e19f3663-cbb5-4bb0-8ea9-8bce66f49925/scratch/move_robot.py

echo "Movement complete. Exiting script to trigger cleanup trap."
sleep 1
