#!/bin/bash
# add-camera-path.sh - Helper script to add new camera paths to MediaMTX configuration
# This script makes it easy to add cameras without manually editing mediamtx.yml

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file location
CONFIG_FILE="$HOME/mediamtx.yml"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: MediaMTX configuration file not found at $CONFIG_FILE${NC}"
    echo "Have you run setup-mediamtx-server.sh yet?"
    exit 1
fi

echo "=========================================="
echo "  Add Camera to MediaMTX"
echo "=========================================="
echo ""
echo "This will add a new camera path to: $CONFIG_FILE"
echo ""

# Get camera name
while true; do
    read -p "Enter camera/stream name (e.g., front-door, garage, backyard): " CAMERA_NAME
    if [ -z "$CAMERA_NAME" ]; then
        echo -e "${RED}Camera name cannot be empty. Please try again.${NC}"
    elif [[ ! "$CAMERA_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo -e "${RED}Camera name can only contain letters, numbers, and hyphens. Please try again.${NC}"
    elif grep -q "^  ${CAMERA_NAME}:" "$CONFIG_FILE"; then
        echo -e "${RED}Camera '$CAMERA_NAME' already exists in configuration. Please choose a different name.${NC}"
    else
        break
    fi
done

# Get publish username
while true; do
    read -p "Enter publish username for this camera (default: $CAMERA_NAME): " PUBLISH_USER
    PUBLISH_USER=${PUBLISH_USER:-$CAMERA_NAME}  # Use camera name as default

    if [[ ! "$PUBLISH_USER" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo -e "${RED}Username can only contain letters, numbers, and hyphens. Please try again.${NC}"
    else
        break
    fi
done

# Get publish password
while true; do
    read -sp "Enter publish password (default: camera): " PUBLISH_PASS
    echo ""
    PUBLISH_PASS=${PUBLISH_PASS:-camera}

    if [ -z "$PUBLISH_PASS" ]; then
        echo -e "${RED}Password cannot be empty. Please try again.${NC}"
    else
        break
    fi
done

# Optional: Custom read credentials
echo ""
read -p "Use custom read credentials? (default uses global viewer:password) (y/n): " CUSTOM_READ

if [[ "$CUSTOM_READ" =~ ^[Yy]$ ]]; then
    read -p "Enter read username: " READ_USER
    read -sp "Enter read password: " READ_PASS
    echo ""
fi

# Summary
echo ""
echo "=========================================="
echo "  Configuration Summary"
echo "=========================================="
echo -e "Camera name:      ${GREEN}$CAMERA_NAME${NC}"
echo -e "Publish user:     ${GREEN}$PUBLISH_USER${NC}"
echo -e "Publish password: ${GREEN}$PUBLISH_PASS${NC}"
if [[ "$CUSTOM_READ" =~ ^[Yy]$ ]]; then
    echo -e "Read user:        ${GREEN}$READ_USER${NC}"
    echo -e "Read password:    ${GREEN}$READ_PASS${NC}"
else
    echo -e "Read access:      ${GREEN}Using global credentials (viewer:password)${NC}"
fi
echo ""
echo "Camera node will publish to:"
echo "  rtsp://$PUBLISH_USER:$PUBLISH_PASS@<server-ip>:8554/$CAMERA_NAME"
echo ""
echo "Viewers will access at:"
echo "  RTSP:   rtsp://viewer:password@<server-ip>:8554/$CAMERA_NAME"
echo "  WebRTC: http://<server-ip>:8889/$CAMERA_NAME"
echo "  HLS:    http://<server-ip>:8888/$CAMERA_NAME"
echo ""
read -p "Add this camera configuration? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
fi

# Backup the config file
BACKUP_FILE="$CONFIG_FILE.backup.$(date +%Y%m%d-%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓${NC} Backup created: $BACKUP_FILE"

# Add the new camera path to the configuration
# Find the line with "paths:" and insert after it
echo ""
echo "Adding camera configuration..."

# Create the new path configuration
NEW_PATH="
  # $CAMERA_NAME
  $CAMERA_NAME:
    publishUser: $PUBLISH_USER
    publishPass: $PUBLISH_PASS"

if [[ "$CUSTOM_READ" =~ ^[Yy]$ ]]; then
    NEW_PATH="$NEW_PATH
    readUser: $READ_USER
    readPass: $READ_PASS"
fi

# Use awk to insert the new path after the "all:" section
awk -v new_path="$NEW_PATH" '
/^  all:/ {
    in_all=1
}
in_all && /^  [a-zA-Z]/ && !/^  all/ {
    print new_path
    in_all=0
}
{print}
END {
    if (in_all) print new_path
}
' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"

mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

echo -e "${GREEN}✓${NC} Camera configuration added"

# Ask to restart MediaMTX service
echo ""
if systemctl is-active --quiet mediamtx.service; then
    read -p "MediaMTX is running. Restart to apply changes? (y/n): " RESTART
    if [[ "$RESTART" =~ ^[Yy]$ ]]; then
        sudo systemctl restart mediamtx.service
        echo -e "${GREEN}✓${NC} MediaMTX restarted"
        sleep 2
        echo ""
        echo "Service status:"
        sudo systemctl status mediamtx.service --no-pager -l
    else
        echo -e "${YELLOW}⚠${NC}  Remember to restart MediaMTX: sudo systemctl restart mediamtx"
    fi
else
    echo -e "${YELLOW}⚠${NC}  MediaMTX is not running. Start it with: sudo systemctl start mediamtx"
fi

echo ""
echo "=========================================="
echo "  Camera Added Successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Configure camera node to use these credentials:"
echo "     Server IP: <this-pi-ip>"
echo "     Stream name: $CAMERA_NAME"
echo ""
echo "  2. On the camera node, edit the systemd service or run init-camera-node.sh"
echo ""
echo "  3. Start the camera stream and verify it appears on this server"
echo ""
echo -e "${GREEN}Done!${NC}"
