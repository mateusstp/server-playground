#!/bin/bash

# Script to configure Ubuntu Server firewall with deny-all policy
# Created: 2025-02-22
# This script must be run with sudo privileges

# Exit on any error
set -e

echo "Starting UFW configuration..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Check if UFW is installed
if ! command -v ufw >/dev/null 2>&1; then
    echo "Installing UFW..."
    apt update
    apt install -y ufw
fi

# Reset UFW to default settings
echo "Resetting UFW to default settings..."
ufw --force reset

# Set default policies
echo "Setting default deny policies..."
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (port 22) to prevent lockout
echo "Allowing SSH connections..."
ufw allow 22/tcp

# Allow Cockpit (port 9090) as required
echo "Allowing Cockpit connections..."
ufw allow 9090/tcp

# Enable UFW
echo "Enabling UFW..."
ufw --force enable

# Display status
echo "Current UFW status:"
ufw status verbose

echo "✅ Firewall configuration completed!"
echo "Warning: All incoming connections except SSH (22) and Cockpit (9090) are now blocked"
echo "Make sure you can still access your server before closing this session"
