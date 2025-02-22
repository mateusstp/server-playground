#!/bin/bash

# Script to install and configure Cockpit on Ubuntu Server 20.04
# Created: 2025-02-22
# This script must be run with sudo privileges

# Exit on any error
set -e

echo "Starting Cockpit installation and configuration..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Check if running on Ubuntu 20.04
if ! grep -q "Ubuntu 20" /etc/os-release; then
    echo "This script is designed for Ubuntu 20.04"
    echo "Current system:"
    cat /etc/os-release
    exit 1
fi

# Update package list
echo "Updating package list..."
apt update

# Install Cockpit
echo "Installing Cockpit..."
apt install -y cockpit

# Enable Cockpit service
echo "Enabling Cockpit service..."
systemctl enable --now cockpit.socket

# Configure firewall if UFW is active
if command -v ufw >/dev/null 2>&1; then
    echo "Configuring firewall..."
    ufw allow 9090/tcp
    echo "Firewall configured to allow Cockpit traffic on port 9090"
fi

# Check if service is running
if systemctl is-active --quiet cockpit.socket; then
    echo "✅ Cockpit installation successful!"
    echo "You can access Cockpit at: https://$(hostname -I | awk '{print $1}'):9090"
    echo "Use your system credentials to log in"
else
    echo "❌ There was a problem starting Cockpit"
    echo "Please check the logs with: journalctl -u cockpit.socket"
    exit 1
fi
