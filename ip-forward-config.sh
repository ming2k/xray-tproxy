#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "Error: Run as root (use sudo)"
    exit 1
fi

cat > /etc/sysctl.d/99-ip-forward.conf << EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF

sysctl -p /etc/sysctl.d/99-ip-forward.conf

