# Plan: Recording and Using Rosbag for mros2-wasm Cartographer

Instead of running the heavy Gazebo simulation every time, we can record the simulation's topics to a `rosbag` and play it back.

---

## Part 1: Recording the Rosbag

To record the sensor and state data, run the Gazebo simulation and teleoperate the robot while recording the required topics.

### 1. Launch Gazebo Simulation
Launch the Turtlebot3 world in Gazebo.
```bash
export TURTLEBOT3_MODEL=burger
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

### 2. Launch Teleoperation
Run the keyboard teleop node to drive the robot around.
```bash
export TURTLEBOT3_MODEL=burger
ros2 run turtlebot3_teleop teleop_keyboard
```

### 3. Record the Rosbag
In a new terminal, record the topics necessary for mapping (Lidar, Odometry, and Transforms):
```bash
ros2 bag record /scan /odom /tf /tf_static -o /home/osslab/turtlebot3_simulation_bag
```
*Drive the robot using teleop for a few minutes to scan the environment, then press `Ctrl+C` in the record terminal to save the bag.*

---

## Part 2: Playback and Offline Cartography

Once recorded, you can run the entire Cartographer + mros2-wasm pipeline without running Gazebo.

### 1. Play the Rosbag
Play back the recorded topics. Use `--clock` to publish the recorded time as the ROS system time (simulation time).
```bash
ros2 bag play /home/osslab/turtlebot3_simulation_bag --clock
```

### 2. Launch Cartographer
Launch the Cartographer node with `use_sim_time:=true` to synchronize with the bag clock.
```bash
source /opt/ros/humble/setup.bash
ros2 launch /home/osslab/ishimotti-mros2-posix/workspace/occupancy_grid_node/launch/cartographer_no_occupancy.launch.py use_sim_time:=true
```

### 3. Run mros2-wasm occupancy_grid_node
Execute the WASM-compiled `occupancy_grid_node` to construct the occupancy grid map from Cartographer's output.
```bash
cd ~/mros2-wasm-stable/cmake_build
~/wamr-fast-interp-stable/product-mini/platforms/linux/build_cr/iwasm \
  --addr-pool=0.0.0.0/0:8000-9000 \
  --max-threads=128 \
  --dir=/tmp \
  occupancy_grid_node.wasm
```
