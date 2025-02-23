#!/bin/bash

# Script to install and configure OpenVPN server
# Created: 2025-02-22

# Exit on any error
set -e

# Environment variables file
ENV_FILE=".env"

# Load environment variables if they exist
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Default values
SERVER_NAME=${SERVER_NAME:-"my-vpn-server"}
ORGANIZATION=${ORGANIZATION:-"MyOrg"}
ORG_UNIT=${ORG_UNIT:-"IT"}
VPN_PORT=${OPENVPN_PORT:-1194}
VPN_PROTOCOL=${OPENVPN_PROTOCOL:-"udp"}
VPN_NETWORK=${OPENVPN_NETWORK:-"10.8.0.0"}
VPN_NETMASK=${OPENVPN_NETMASK:-"255.255.255.0"}
DNS1=${OPENVPN_DNS1:-"8.8.8.8"}
DNS2=${OPENVPN_DNS2:-"8.8.4.4"}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Function to install OpenVPN and dependencies
install_openvpn() {
    echo "Installing OpenVPN and dependencies..."
    apt update
    apt install -y openvpn easy-rsa

    # Create and set up easy-rsa directory
    echo "Setting up easy-rsa directory..."
    rm -rf /etc/openvpn/easy-rsa
    make-cadir /etc/openvpn/easy-rsa
    
    # Create required directories
    mkdir -p /etc/openvpn/clients
    mkdir -p /etc/openvpn/client-configs
    
    # Set proper permissions
    chmod 700 /etc/openvpn/clients
    chmod 700 /etc/openvpn/client-configs
    
    # Move to easy-rsa directory and ensure we're there
    cd /etc/openvpn/easy-rsa || exit 1
    
    # Configure easy-rsa variables
    echo "Configuring easy-rsa variables..."
    cat > vars << EOF
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "California"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "$ORGANIZATION"
set_var EASYRSA_REQ_OU         "$ORG_UNIT"
set_var EASYRSA_REQ_EMAIL      "admin@$SERVER_NAME"
set_var EASYRSA_REQ_CN         "$SERVER_NAME"
EOF

    # Initialize the PKI
    echo "Initializing PKI..."
    ./easyrsa init-pki
    
    # Ensure PKI directory exists and has correct permissions
    chmod -R 700 pki
    
    # Create CA certificate (non-interactive)
    echo "Creating CA certificate..."
    ./easyrsa --batch --req-cn="$ORGANIZATION CA" build-ca nopass
    
    # Generate server certificate and key (non-interactive)
    echo "Generating server certificate and key..."
    ./easyrsa --batch build-server-full "$SERVER_NAME" nopass
    
    # Generate Diffie-Hellman parameters
    echo "Generating DH parameters (this may take a while)..."
    ./easyrsa gen-dh
    
    # Generate TLS key for additional security
    echo "Generating TLS key..."
    cd /etc/openvpn || exit 1
    openvpn --genkey secret ta.key
    chmod 600 ta.key
}

# Function to configure OpenVPN server
configure_server() {
    echo "Configuring OpenVPN server..."
    
    # Copy required files to OpenVPN directory
    cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/
    cp "/etc/openvpn/easy-rsa/pki/issued/$SERVER_NAME.crt" "/etc/openvpn/server.crt"
    cp "/etc/openvpn/easy-rsa/pki/private/$SERVER_NAME.key" "/etc/openvpn/server.key"
    cp /etc/openvpn/easy-rsa/pki/dh.pem /etc/openvpn/

    # Create server configuration
    cat > /etc/openvpn/server.conf << EOF
port $VPN_PORT
proto $VPN_PROTOCOL
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
server $VPN_NETWORK $VPN_NETMASK
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS $DNS1"
push "dhcp-option DNS $DNS2"
keepalive 10 120
cipher AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

    # Create log directory
    mkdir -p /var/log/openvpn

    # Enable IP forwarding
    echo "Enabling IP forwarding..."
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn.conf
    sysctl --system

    # Configure firewall for OpenVPN
    if command -v ufw >/dev/null 2>&1; then
        echo "Configuring UFW for OpenVPN..."
        ufw allow $VPN_PORT/$VPN_PROTOCOL
        
        # Get primary network interface
        PRIMARY_NIC=$(ip route | grep default | awk '{print $5}')
        
        # Add NAT rules
        cat > /etc/ufw/before.rules << EOF
# NAT for OpenVPN
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s $VPN_NETWORK/24 -o $PRIMARY_NIC -j MASQUERADE
COMMIT
EOF
        
        # Enable UFW forwarding
        sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
        
        # Reload UFW
        ufw disable
        ufw enable
    fi
}

# Function to start OpenVPN service
start_openvpn() {
    echo "Starting OpenVPN service..."
    systemctl enable openvpn@server
    systemctl start openvpn@server
    
    echo "Checking OpenVPN status..."
    systemctl status openvpn@server
}

# Main execution
echo "Starting OpenVPN server installation and configuration..."

# Create backup directory
BACKUP_DIR="/etc/openvpn/backup-$(date +%Y%m%d-%H%M%S)"
if [ -d "/etc/openvpn" ]; then
    echo "Creating backup of existing OpenVPN configuration..."
    mkdir -p "$BACKUP_DIR"
    cp -r /etc/openvpn/* "$BACKUP_DIR/"
fi

# Run installation steps
install_openvpn
configure_server
start_openvpn

echo "✅ OpenVPN server installation and configuration complete!"
echo "Use the manage_vpn_clients.sh script to create client configurations."
