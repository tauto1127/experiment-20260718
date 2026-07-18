#!/usr/bin/env python3
import sys
import os
import math

# Add ROS 2 python libraries to path if needed (will be handled by python in sourced environment)
try:
    import rclpy
    import rosbag2_py
    from rclpy.serialization import deserialize_message
    from nav_msgs.msg import Odometry
    from sensor_msgs.msg import LaserScan
except ImportError:
    print("Error: Could not import ROS 2 Python modules. Please run this script in a sourced environment.")
    sys.exit(1)

def analyze_bag(bag_path):
    if not os.path.exists(bag_path):
        print(f"Error: Bag path '{bag_path}' does not exist.")
        sys.exit(1)

    print(f"Opening bag database at: {bag_path}")
    
    # Initialize reader
    reader = rosbag2_py.SequentialReader()
    storage_options = rosbag2_py.StorageOptions(uri=bag_path, storage_id='sqlite3')
    converter_options = rosbag2_py.ConverterOptions(
        input_serialization_format='cdr',
        output_serialization_format='cdr')
    
    try:
        reader.open(storage_options, converter_options)
    except Exception as e:
        print(f"Failed to open bag: {e}")
        # Try to find the db3 file directly if directory
        if os.path.isdir(bag_path):
            files = [f for f in os.listdir(bag_path) if f.endswith('.db3')]
            if files:
                db_path = os.path.join(bag_path, files[0])
                print(f"Retrying with database file: {db_path}")
                storage_options.uri = db_path
                reader.open(storage_options, converter_options)
            else:
                sys.exit(1)
        else:
            sys.exit(1)

    # Statistics variables
    odom_x = []
    odom_y = []
    total_distance = 0.0
    last_x, last_y = None, None
    
    scan_count = 0
    total_lidar_rays = 0
    min_laser_dist = 999.0
    max_laser_dist = -999.0
    
    topic_counts = {}

    while reader.has_next():
        topic, data, timestamp = reader.read_next()
        topic_counts[topic] = topic_counts.get(topic, 0) + 1
        
        if topic == '/odom':
            try:
                msg = deserialize_message(data, Odometry)
                x = msg.pose.pose.position.x
                y = msg.pose.pose.position.y
                odom_x.append(x)
                odom_y.append(y)
                
                if last_x is not None and last_y is not None:
                    dist = math.sqrt((x - last_x)**2 + (y - last_y)**2)
                    # Ignore tiny jitter
                    if dist > 0.001:
                        total_distance += dist
                last_x, last_y = x, y
            except Exception as e:
                pass
                
        elif topic == '/scan':
            try:
                msg = deserialize_message(data, LaserScan)
                scan_count += 1
                valid_ranges = [r for r in msg.ranges if r > msg.range_min and r < msg.range_max]
                total_lidar_rays += len(valid_ranges)
                if valid_ranges:
                    min_laser_dist = min(min_laser_dist, min(valid_ranges))
                    max_laser_dist = max(max_laser_dist, max(valid_ranges))
            except Exception as e:
                pass

    print("\n=============================================")
    print("         ROSBAG OBJECTIVE ANALYSIS")
    print("=============================================")
    print(f"Bag Directory: {bag_path}")
    print("\nTopic Message Counts:")
    for topic, count in sorted(topic_counts.items()):
        print(f"  {topic}: {count} messages")

    if odom_x and odom_y:
        min_x, max_x = min(odom_x), max(odom_x)
        min_y, max_y = min(odom_y), max(odom_y)
        dx = max_x - min_x
        dy = max_y - min_y
        
        print("\nTrajectory Statistics:")
        print(f"  Total Distance Traveled: {total_distance:.2f} meters")
        print(f"  X Range: [{min_x:.2f}, {max_x:.2f}] (Span: {dx:.2f}m)")
        print(f"  Y Range: [{min_y:.2f}, {max_y:.2f}] (Span: {dy:.2f}m)")
        print(f"  Bounding Box Area: {dx * dy:.2f} square meters")
        
        # Calculate standard deviation to represent spatial spread of robot
        mean_x = sum(odom_x) / len(odom_x)
        mean_y = sum(odom_y) / len(odom_y)
        var_x = sum((x - mean_x)**2 for x in odom_x) / len(odom_x)
        var_y = sum((y - mean_y)**2 for y in odom_y) / len(odom_y)
        std_x = math.sqrt(var_x)
        std_y = math.sqrt(var_y)
        print(f"  Exploration Spread (Std Dev): X={std_x:.2f}m, Y={std_y:.2f}m")
    else:
        print("\nTrajectory Statistics: No /odom data found.")

    if scan_count > 0:
        avg_rays = total_lidar_rays / scan_count if scan_count > 0 else 0
        print("\nLidar Sensor Coverage:")
        print(f"  Total Lidar Scans: {scan_count}")
        print(f"  Average valid rays per scan: {avg_rays:.1f}")
        print(f"  Observed Distances: Min={min_laser_dist:.2f}m, Max={max_laser_dist:.2f}m")
    else:
        print("\nLidar Sensor Coverage: No /scan data found.")
    print("=============================================\n")

if __name__ == '__main__':
    bag = "/home/osslab/turtlebot3_simulation_bag"
    if len(sys.argv) > 1:
        bag = sys.argv[1]
    analyze_bag(bag)
