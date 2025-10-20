#!/bin/bash
# init-camera-node.sh - One-time setup script for camera nodes after SD card cloning
# This script configures the hostname and stream name for each Raspberry Pi camera

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

echo "=========================================="
echo "  Camera Node Setup Script"
echo "=========================================="
echo ""
echo "This script will configure:"
echo "  1. Hostname (network identifier)"
echo "  2. Stream name (RTSP path)"
echo ""

# Get hostname
while true; do
    read -p "Enter hostname for this Pi (e.g., pi-front-door, pi-garage): " HOSTNAME
    if [ -z "$HOSTNAME" ]; then
        echo -e "${RED}Hostname cannot be empty. Please try again.${NC}"
    elif [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo -e "${RED}Hostname can only contain letters, numbers, and hyphens. Please try again.${NC}"
    else
        break
    fi
done

# Get stream name
while true; do
    read -p "Enter stream name for this camera (e.g., front-door, backyard-cam): " STREAM_NAME
    if [ -z "$STREAM_NAME" ]; then
        echo -e "${RED}Stream name cannot be empty. Please try again.${NC}"
    elif [[ ! "$STREAM_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo -e "${RED}Stream name can only contain letters, numbers, and hyphens. Please try again.${NC}"
    else
        break
    fi
done

# Get server IP
while true; do
    read -p "Enter MediaMTX server IP address (e.g., 192.168.1.100): " SERVER_IP
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}Server IP cannot be empty. Please try again.${NC}"
    elif [[ ! "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${RED}Invalid IP address format. Please try again.${NC}"
    else
        break
    fi
done

echo ""
echo "=========================================="
echo "  Configuration Summary"
echo "=========================================="
echo -e "Hostname:    ${GREEN}$HOSTNAME${NC}"
echo -e "Stream name: ${GREEN}$STREAM_NAME${NC}"
echo -e "Server IP:   ${GREEN}$SERVER_IP${NC}"
echo ""
read -p "Apply this configuration? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

echo ""
echo "Applying configuration..."

# Update hostname
echo "$HOSTNAME" > /etc/hostname
echo -e "${GREEN}✓${NC} Updated /etc/hostname"

# Update /etc/hosts
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
echo -e "${GREEN}✓${NC} Updated /etc/hosts"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Update systemd service file with environment variables
SERVICE_EXAMPLE="$PROJECT_DIR/camera-stream.service.example"
SERVICE_FILE="/etc/systemd/system/camera-stream.service"

if [ -f "$SERVICE_EXAMPLE" ]; then
    # Copy service file and add environment variables
    cp "$SERVICE_EXAMPLE" "$SERVICE_FILE"

    # Add environment variables after the existing Environment line
    sed -i "/^Environment=\"HOME=\/home\/pi\"/a Environment=\"SERVER_IP=$SERVER_IP\"\nEnvironment=\"STREAM_NAME=$STREAM_NAME\"" "$SERVICE_FILE"

    # Update the ExecStart path to use the correct project directory
    sed -i "s|ExecStart=/home/pi/scripts/publish-stream.sh|ExecStart=$SCRIPT_DIR/publish-stream.sh|" "$SERVICE_FILE"

    echo -e "${GREEN}✓${NC} Created systemd service with environment variables"

    # Reload systemd to pick up the new service
    systemctl daemon-reload
    echo -e "${GREEN}✓${NC} Reloaded systemd daemon"
else
    echo -e "${RED}✗${NC} Warning: camera-stream.service.example not found at $SERVICE_EXAMPLE"
fi

echo ""
echo "=========================================="
echo "  Configuration Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Reboot this Pi for hostname change to take effect"
echo "  2. After reboot, start streaming with: sudo systemctl start camera-stream"
echo "  3. Enable auto-start on boot: sudo systemctl enable camera-stream"
echo ""
echo "Network access:"
echo "  SSH: ssh pi@$HOSTNAME.local"
echo "  Stream: rtsp://$SERVER_IP:8554/$STREAM_NAME"
echo ""
echo "Service management:"
echo "  Status:  sudo systemctl status camera-stream"
echo "  Logs:    journalctl -u camera-stream -f"
echo ""
read -p "Reboot now? (y/n): " REBOOT

if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    reboot
else
    echo -e "${YELLOW}Remember to reboot manually for changes to take effect!${NC}"
fi
