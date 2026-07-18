#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist
from sensor_msgs.msg import LaserScan
import time
import sys

class Explorer(Node):
    def __init__(self):
        super().__init__('explorer')
        self.publisher_ = self.create_publisher(Twist, '/cmd_vel', 10)
        self.subscription = self.create_subscription(
            LaserScan,
            '/scan',
            self.scan_callback,
            rclpy.qos.qos_profile_sensor_data  # LaserScan usually uses Best Effort QoS
        )
        self.obstacle_detected = False
        self.min_distance_to_obstacle = 999.0

    def scan_callback(self, msg):
        # Lidar ranges are 360 degrees (0 index is front, counter-clockwise)
        # Check the front arc: -30 degrees (330) to +30 degrees (30)
        ranges_len = len(msg.ranges)
        if ranges_len == 0:
            return

        front_arc = []
        # Safely collect ranges in the front 60-degree cone
        for i in range(-30, 30):
            idx = i % ranges_len
            val = msg.ranges[idx]
            # Ignore zero, nan, inf, and invalid readings
            if val > 0.05 and val < 5.0:
                front_arc.append(val)

        if front_arc:
            self.min_distance_to_obstacle = min(front_arc)
            # Threshold of 0.6 meters for obstacle avoidance
            if self.min_distance_to_obstacle < 0.6:
                self.obstacle_detected = True
            else:
                self.obstacle_detected = False
        else:
            self.min_distance_to_obstacle = 999.0
            self.obstacle_detected = False

def main(args=None):
    rclpy.init(args=args)
    node = Explorer()
    
    start_time = time.time()
    duration = 90.0  # Run for 90 seconds to explore more of the map
    msg = Twist()
    
    print("Robot autonomous mapping explorer started.")
    try:
        while rclpy.ok():
            elapsed = time.time() - start_time
            if elapsed >= duration:
                break
                
            if node.obstacle_detected:
                # Obstacle close -> Turn in place to clear path
                msg.linear.x = 0.0
                msg.angular.z = 0.5  # Turn
                node.get_logger().info(f'Obstacle detected at {node.min_distance_to_obstacle:.2f}m! Turning...', throttle_duration_sec=1.0)
            else:
                # Path clear -> Move forward in a gentle winding curve to cover area
                msg.linear.x = 0.15
                msg.angular.z = 0.1
                node.get_logger().info(f'Path clear. Winding forward... (Elapsed: {elapsed:.1f}s)', throttle_duration_sec=3.0)
                
            node.publisher_.publish(msg)
            
            # Spin once to process Lidar scan callbacks
            rclpy.spin_once(node, timeout_sec=0.1)
            time.sleep(0.1)
            
    except KeyboardInterrupt:
        pass
    finally:
        # Stop the robot on exit
        msg_stop = Twist()
        msg_stop.linear.x = 0.0
        msg_stop.angular.z = 0.0
        node.publisher_.publish(msg_stop)
        node.get_logger().info('Stopping robot and exiting explorer.')
        
        node.destroy_node()
        rclpy.shutdown()
        print("Explorer script finished.")
        sys.exit(0)

if __name__ == '__main__':
    main()
