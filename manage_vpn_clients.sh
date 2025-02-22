#!/bin/bash

# Script to manage OpenVPN client configurations
# Created: 2025-02-22

# Exit on any error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Load environment variables if they exist
if [ -f "/.env" ]; then
    source "/.env"
fi

# Default values
SERVER_NAME=${SERVER_NAME:-"my-vpn-server"}
ORGANIZATION=${ORGANIZATION:-"MyOrg"}
ORG_UNIT=${ORG_UNIT:-"IT"}
CLIENT_DIR="/etc/openvpn/clients"
EASYRSA_DIR="/etc/openvpn/easy-rsa"
OUTPUT_DIR="/etc/openvpn/client-configs"

# Create necessary directories
mkdir -p "$CLIENT_DIR"
mkdir -p "$OUTPUT_DIR"

# Function to create a new client
create_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo "Usage: $0 create <client_name>"
        exit 1
    fi
    
    echo "Creating certificate for client: $client_name"
    
    # Generate client certificate and key
    cd "$EASYRSA_DIR"
    ./easyrsa --batch build-client-full "$client_name" nopass
    
    # Create client configuration directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR/$client_name"
    
    # Get server IP address
    SERVER_IP=$(curl -s ifconfig.me || wget -qO- ifconfig.me)
    
    # Use environment variables or defaults
    VPN_PORT=${OPENVPN_PORT:-1194}
    VPN_PROTOCOL=${OPENVPN_PROTOCOL:-"udp"}
    
    # Generate client configuration
    cat > "$OUTPUT_DIR/$client_name/$client_name.ovpn" << EOF
client
dev tun
proto $VPN_PROTOCOL
remote $SERVER_IP $VPN_PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
auth SHA256
key-direction 1
verb 3
EOF
    
    # Append certificates and keys
    echo "<ca>" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    cat "$EASYRSA_DIR/pki/ca.crt" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    echo "</ca>" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    
    echo "<cert>" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    cat "$EASYRSA_DIR/pki/issued/$client_name.crt" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    echo "</cert>" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    
    echo "<key>" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    cat "$EASYRSA_DIR/pki/private/$client_name.key" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    echo "</key>" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    
    echo "<tls-auth>" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    cat "/etc/openvpn/ta.key" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    echo "</tls-auth>" >> "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    
    # Set secure permissions
    chmod 400 "$OUTPUT_DIR/$client_name/$client_name.ovpn"
    
    echo "✅ Client configuration created: $OUTPUT_DIR/$client_name/$client_name.ovpn"
    echo "Transfer this file securely to the client device."
}

# Function to revoke a client certificate
revoke_client() {
    local client_name=$1
    
    if [ -z "$client_name" ]; then
        echo "Usage: $0 revoke <client_name>"
        exit 1
    fi
    
    echo "Revoking certificate for client: $client_name"
    
    cd "$EASYRSA_DIR"
    ./easyrsa --batch revoke "$client_name"
    ./easyrsa gen-crl
    
    # Copy the CRL to the OpenVPN directory
    cp -f "$EASYRSA_DIR/pki/crl.pem" /etc/openvpn/
    
    # Remove client configuration
    rm -rf "$OUTPUT_DIR/$client_name"
    
    # Restart OpenVPN service to apply changes
    systemctl restart openvpn@server
    
    echo "✅ Client certificate revoked and VPN service restarted"
}

# Function to list all clients
list_clients() {
    echo "Active VPN Clients:"
    echo "------------------"
    
    if [ -d "$EASYRSA_DIR/pki/issued" ]; then
        for cert in "$EASYRSA_DIR/pki/issued/"*.crt; do
            if [ -f "$cert" ]; then
                client_name=$(basename "$cert" .crt)
                if [ "$client_name" != "server" ]; then
                    echo "- $client_name"
                fi
            fi
        done
    else
        echo "No clients found"
    fi
}

# Main script execution
case "$1" in
    create)
        create_client "$2"
        ;;
    revoke)
        revoke_client "$2"
        ;;
    list)
        list_clients
        ;;
    *)
        echo "Usage: $0 {create|revoke|list} [client_name]"
        echo "Examples:"
        echo "  $0 create john_doe  - Create a new client configuration"
        echo "  $0 revoke john_doe  - Revoke a client's certificate"
        echo "  $0 list            - List all active clients"
        exit 1
        ;;
esac
