#!/bin/bash

# Script to apply permissions to all configuration scripts
# Created: 2025-02-22

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# List of scripts to check and modify
SCRIPTS=(
    "setup_cockpit.sh"
    "configure_firewall.sh"
    "setup_ngrok.sh"
    "setup_openvpn.sh"
    "manage_vpn_clients.sh"
)

# Function to apply permissions to a script
apply_permissions() {
    local script=$1
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        echo "❌ Error: $script not found in $SCRIPT_DIR"
        return 1
    fi

    echo "Applying execute permissions to $script..."
    chmod +x "$SCRIPT_DIR/$script"

    if [ -x "$SCRIPT_DIR/$script" ]; then
        echo "✅ Permissions successfully applied to $script"
        return 0
    else
        echo "❌ Failed to apply permissions to $script"
        return 1
    fi
}

# Main execution
echo "Starting permission application process..."
EXIT_CODE=0

for script in "${SCRIPTS[@]}"; do
    if ! apply_permissions "$script"; then
        EXIT_CODE=1
    fi
done

if [ $EXIT_CODE -eq 0 ]; then
    echo "\n✅ All permissions successfully applied!"
    echo "You can now run the scripts with:"
    echo "  - Setup Cockpit: sudo ./setup_cockpit.sh"
    echo "  - Configure Firewall: sudo ./configure_firewall.sh"
else
    echo "\n❌ Some permissions could not be applied. Please check the errors above."
fi

exit $EXIT_CODE
