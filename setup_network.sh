#!/bin/bash
set -euo pipefail

IFACE=${MROS2_IFACE:-eth0}
HOST_IP=${MROS2_HOST_IP:-192.168.100.3}

echo "=== Checking physical network interface ==="
if ! ip link show dev "${IFACE}" >/dev/null 2>&1; then
    echo "ERROR: network interface ${IFACE} does not exist" >&2
    exit 1
fi

if ! ip -4 addr show dev "${IFACE}" | grep -q "inet ${HOST_IP}/"; then
    echo "ERROR: ${IFACE} does not have ${HOST_IP}" >&2
    ip -4 addr show dev "${IFACE}" >&2
    exit 1
fi

echo "Using ${IFACE} with ${HOST_IP}; no virtual network interface is configured."
ip -4 addr show dev "${IFACE}"
echo "========================================="
