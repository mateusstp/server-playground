#!/bin/bash

# Script to setup and run ngrok for HTTPS and TCP tunneling
# Created: 2025-02-22

# Exit on any error
set -e

# Environment variables file
ENV_FILE=".env"

# Check if .env exists, if not create it with default values
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" << EOF
# Ngrok configuration
NGROK_AUTH_TOKEN=""
NGROK_HTTPS_PORT="8080"
NGROK_TCP_PORT="4000"
NGROK_REGION="us"  # Options: us, eu, au, ap, sa, jp, in
EOF
    echo "Created $ENV_FILE with default values. Please edit it with your configuration."
    exit 1
fi

# Source the environment variables
source "$ENV_FILE"

# Check if ngrok is installed
check_ngrok() {
    if ! command -v ngrok &> /dev/null; then
        echo "Ngrok not found. Installing..."
        if command -v snap &> /dev/null; then
            sudo snap install ngrok
        else
            # Install using package manager or curl
            curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
              sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
              echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
              sudo tee /etc/apt/sources.list.d/ngrok.list && \
              sudo apt update && sudo apt install ngrok
        fi
    fi
}

# Validate environment variables
validate_env() {
    if [ -z "$NGROK_AUTH_TOKEN" ]; then
        echo "❌ Error: NGROK_AUTH_TOKEN is not set in $ENV_FILE"
        echo "Please get your auth token from https://dashboard.ngrok.com/get-started/your-authtoken"
        exit 1
    fi

    if [ -z "$NGROK_HTTPS_PORT" ]; then
        echo "Using default HTTPS port 8080"
        NGROK_HTTPS_PORT="8080"
    fi

    if [ -z "$NGROK_TCP_PORT" ]; then
        echo "Using default TCP port 4000"
        NGROK_TCP_PORT="4000"
    fi

    if [ -z "$NGROK_REGION" ]; then
        echo "Using default region 'us'"
        NGROK_REGION="us"
    fi
}

# Configure ngrok
configure_ngrok() {
    echo "Configuring ngrok..."
    ngrok config add-authtoken "$NGROK_AUTH_TOKEN"

    # Create ngrok configuration file
    cat > ngrok.yml << EOF
version: "2"
authtoken: ${NGROK_AUTH_TOKEN}
region: ${NGROK_REGION}
tunnels:
  https-tunnel:
    addr: ${NGROK_HTTPS_PORT}
    proto: http
  tcp-tunnel:
    addr: ${NGROK_TCP_PORT}
    proto: tcp
EOF
}

# Start ngrok
start_ngrok() {
    echo "Starting ngrok tunnels..."
    echo "HTTPS tunnel will forward to localhost:${NGROK_HTTPS_PORT}"
    echo "TCP tunnel will forward to localhost:${NGROK_TCP_PORT}"
    
    # Start ngrok in background using the configuration file
    ngrok start --all --config=ngrok.yml &
    
    # Wait for ngrok to start
    sleep 5
    
    # Get tunnel URLs
    echo "\nTunnel Information:"
    curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*"' | cut -d'"' -f4
}

# Main execution
echo "Setting up ngrok tunnels..."

# Run the setup steps
check_ngrok
validate_env
configure_ngrok
start_ngrok

echo "\n✅ Ngrok setup complete!"
echo "You can view the ngrok status dashboard at: http://localhost:4040"
echo "To stop ngrok, run: pkill ngrok"
