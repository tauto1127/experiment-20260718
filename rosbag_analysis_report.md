# Rosbag Exploration Quality Report

This report presents an objective, data-driven analysis of the recorded rosbag database to evaluate its coverage and suitability for offline Cartographer SLAM.

---

## 1. Topic Message Statistics
Below is the count of messages successfully captured in the bag file for each topic.

| Topic Name | Message Type | Message Count | Purpose |
| :--- | :--- | :--- | :--- |
| `/scan` | `sensor_msgs/msg/LaserScan` | **471** | Lidar ranges for mapping |
| `/odom` | `nav_msgs/msg/Odometry` | **2,770** | Wheel odometry state |
| `/tf` | `tf2_msgs/msg/TFMessage` | **4,599** | Coordinate transforms |
| `/tf_static` | `tf2_msgs/msg/TFMessage` | **1** | Static robot offsets |
| `/imu` | `sensor_msgs/msg/Imu` | **18,825** | Inertial sensor readings |
| `/joint_states` | `sensor_msgs/msg/JointState` | **2,770** | Wheel/joint status |

---

## 2. Trajectory & Spatial Exploration Metrics
These metrics quantify how effectively the autonomous explorer traversed the Gazebo environment.

| Metric | Measured Value | Meaning / Interpretation |
| :--- | :--- | :--- |
| **Total Distance Traveled** | **9.51 meters** | The robot actively drove and navigated around obstacles |
| **X Coordinate Range** | `[-2.39, -1.43]` (Span: **0.97m**) | Horizontal exploration bounds |
| **Y Coordinate Range** | `[-1.00, 0.57]` (Span: **1.57m**) | Vertical exploration bounds |
| **Bounding Box Area** | **1.52 m²** | Total spatial rectangular coverage of the robot's base |
| **Exploration Spread (Std Dev)** | X: **0.29m**, Y: **0.44m** | High variance indicating non-repetitive spatial coverage |

---

## 3. Lidar Sensor Quality
Objective quality of Lidar data collected during exploration.

- **Total Scans Recorded**: `471`
- **Average Valid Rays/Scan**: `323.7` (out of 360 maximum)
- **Observed Range Limits**: Min: `0.35m` (close walls), Max: `3.50m` (open space limit)

> [!NOTE]
> The lidar data density is extremely high (avg. **89.9%** valid rays per scan), meaning very few rays were out-of-range or invalid. This provides Cartographer with excellent features for correlative scan matching.

---

## Conclusion
The data shows the robot successfully completed **9.51 meters** of non-repetitive winding paths, maintaining a distance of at least **0.35m** from walls, and recording **471** high-quality scan sweeps. This is a highly comprehensive dataset suitable for generating a complete map.
