#!/bin/bash
# Exit on error
set -e

PASSWORD="BitVisor!"

echo "=== Setting up Virtual Network Interfaces ==="

# Delete existing veth_host if it exists (which also deletes veth_wasm)
if ip link show veth_host &>/dev/null; then
    echo "Deleting existing veth_host..."
    echo "$PASSWORD" | sudo -S ip link del veth_host || true
fi

# Create veth pair
echo "Creating veth pair (veth_host <-> veth_wasm)..."
echo "$PASSWORD" | sudo -S ip link add veth_host type veth peer name veth_wasm

# Configure IP address for host side (192.168.100.10)
# (mros2-wasm binds to 192.168.100.11 on the veth_wasm side)
echo "Assigning IP 192.168.100.10/24 to veth_host..."
echo "$PASSWORD" | sudo -S ip addr add 192.168.100.10/24 dev veth_host

# Bring interfaces UP
echo "Bringing veth interfaces UP..."
echo "$PASSWORD" | sudo -S ip link set dev veth_host up
echo "$PASSWORD" | sudo -S ip link set dev veth_wasm up

# Enable promiscuous mode on both ends so multicast packets are not dropped
echo "Enabling promiscuous mode..."
echo "$PASSWORD" | sudo -S ip link set dev veth_host promisc on
echo "$PASSWORD" | sudo -S ip link set dev veth_wasm promisc on

echo "Network interfaces setup successfully:"
ip addr show dev veth_host
echo "========================================="
