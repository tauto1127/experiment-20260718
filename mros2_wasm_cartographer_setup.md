# mros2-wasm Cartographer Setup Summary

This document summarizes the setup steps and commands for running `mros2-wasm` with ROS 2 Cartographer as described in the Heptabase card from July 17, 2026.

## Overview

The setup splits the cartography pipeline:
- **ROS 2 Side**: Gazebo (simulating Turtlebot3), Cartographer (`cartographer_node` only, no `occupancy_grid_node`), and teleoperation.
- **WASM/mros2 Side**: Runs the `occupancy_grid_node.wasm` under WAMR (`iwasm`), which publishes the `/map` topic based on Cartographer's output.

---

## Startup Steps & Commands

### 1. Gazebo Simulation
Launch the Turtlebot3 simulation environment in Gazebo.
```bash
export TURTLEBOT3_MODEL=burger
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

### 2. ROS 2 Cartographer
Launch Cartographer and RViz. Note that this launch script is custom-configured to **only** run the `cartographer_node` (and not `occupancy_grid_node`), allowing the WASM application to handle map/occupancy grid publication.
```bash
source /opt/ros/humble/setup.bash
ros2 launch /home/osslab/ishimotti-mros2-posix/workspace/occupancy_grid_node/launch/cartographer_no_occupancy.launch.py use_sim_time:=true
```

### 3. Keyboard Teleoperation
Run the teleop node to control the Turtlebot3 robot in Gazebo.
```bash
export TURTLEBOT3_MODEL=burger
ros2 run turtlebot3_teleop teleop_keyboard
```

### 4. mros2-wasm occupancy_grid_node
Execute the WASM-compiled `occupancy_grid_node` using the WAMR interpreter (`iwasm`).

- **Directory**: `~/mros2-wasm-stable/cmake_build`
- **Execution Command**:
```bash
~/wamr-fast-interp-stable/product-mini/platforms/linux/build_cr/iwasm \
  --addr-pool=0.0.0.0/0:8000-9000 \
  --max-threads=128 \
  --dir=/tmp \
  occupancy_grid_node.wasm
```

---

## File Verification Status

The following paths and files required for the setup have been verified to exist:

- [cartographer_no_occupancy.launch.py](file:///home/osslab/ishimotti-mros2-posix/workspace/occupancy_grid_node/launch/cartographer_no_occupancy.launch.py)
- [occupancy_grid_node.wasm](file:///home/osslab/mros2-wasm-stable/cmake_build/occupancy_grid_node.wasm)
- WAMR interpreter: `~/wamr-fast-interp-stable/product-mini/platforms/linux/build_cr/iwasm`
