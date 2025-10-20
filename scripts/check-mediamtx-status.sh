#!/bin/bash
# check-mediamtx-status.sh - Monitor MediaMTX server status and active streams
# Provides an overview of the MediaMTX server health and connected cameras

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
API_URL="http://127.0.0.1:9997"
CONFIG_FILE="$HOME/mediamtx.yml"

echo "=========================================="
echo "  MediaMTX Server Status"
echo "=========================================="
echo ""

# Check if MediaMTX service is running
echo -e "${BLUE}[Service Status]${NC}"
if systemctl is-active --quiet mediamtx.service; then
    echo -e "Status: ${GREEN}RUNNING${NC}"
    UPTIME=$(systemctl show mediamtx.service --property=ActiveEnterTimestamp --value)
    echo "Uptime: $UPTIME"
else
    echo -e "Status: ${RED}STOPPED${NC}"
    echo ""
    echo "Start MediaMTX with: sudo systemctl start mediamtx"
    exit 1
fi

echo ""

# Get server IP addresses
echo -e "${BLUE}[Network Information]${NC}"
echo "Server IP addresses:"
hostname -I | tr ' ' '\n' | grep -v '^$' | while read ip; do
    echo "  - $ip"
done
echo ""

# Check API availability
echo -e "${BLUE}[API Status]${NC}"
if curl -s "$API_URL/v3/config/get" > /dev/null 2>&1; then
    echo -e "API: ${GREEN}Available${NC} at $API_URL"
else
    echo -e "API: ${YELLOW}Not responding${NC}"
    echo "API may not be enabled in mediamtx.yml"
fi
echo ""

# List configured paths from config file
echo -e "${BLUE}[Configured Camera Paths]${NC}"
if [ -f "$CONFIG_FILE" ]; then
    echo "Reading from: $CONFIG_FILE"
    echo ""

    # Extract path names (excluding 'all')
    PATHS=$(grep -E "^  [a-zA-Z0-9-]+:" "$CONFIG_FILE" | grep -v "^  all:" | sed 's/://g' | sed 's/^  //')

    if [ -z "$PATHS" ]; then
        echo -e "${YELLOW}No camera paths configured yet${NC}"
        echo "Add cameras with: ./scripts/add-camera-path.sh"
    else
        # Get primary IP (first non-loopback IP)
        SERVER_IP=$(hostname -I | awk '{print $1}')

        echo "Path Name          | Publish Auth | URLs"
        echo "-------------------|--------------|----------------------------------------"

        while IFS= read -r path; do
            # Try to extract publish credentials for this path
            PUBLISH_USER=$(awk "/^  ${path}:$/,/^  [a-zA-Z]/" "$CONFIG_FILE" | grep "publishUser:" | head -1 | awk '{print $2}')

            if [ -z "$PUBLISH_USER" ]; then
                PUBLISH_USER="N/A"
            fi

            # Show path info
            printf "%-18s | %-12s | " "$path" "$PUBLISH_USER"

            # Show primary access URL
            echo "rtsp://$SERVER_IP:8554/$path"
        done <<< "$PATHS"
    fi
else
    echo -e "${YELLOW}Configuration file not found: $CONFIG_FILE${NC}"
fi

echo ""

# Try to get active streams from API
echo -e "${BLUE}[Active Streams]${NC}"
if curl -s "$API_URL/v3/paths/list" > /dev/null 2>&1; then
    ACTIVE_STREAMS=$(curl -s "$API_URL/v3/paths/list" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | wc -l)

    if [ "$ACTIVE_STREAMS" -gt 0 ]; then
        echo -e "${GREEN}$ACTIVE_STREAMS active stream(s)${NC}"
        echo ""

        # List each active stream
        curl -s "$API_URL/v3/paths/list" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | while read stream; do
            echo -e "${GREEN}✓${NC} $stream"

            # Try to get reader count
            READERS=$(curl -s "$API_URL/v3/paths/get/$stream" | grep -o '"numReaders":[0-9]*' | cut -d: -f2)
            if [ -n "$READERS" ]; then
                echo "  └─ $READERS viewer(s) connected"
            fi
        done
    else
        echo -e "${YELLOW}No active streams${NC}"
        echo "Waiting for cameras to connect..."
    fi
else
    echo -e "${YELLOW}Unable to query active streams (API not available)${NC}"
    echo ""
    echo "Check manually with: journalctl -u mediamtx -n 50"
fi

echo ""

# Show access URLs
echo -e "${BLUE}[Access URLs Template]${NC}"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Replace <stream-name> with your camera path:"
echo ""
echo -e "${CYAN}RTSP (VLC, NVR software):${NC}"
echo "  rtsp://viewer:password@$SERVER_IP:8554/<stream-name>"
echo ""
echo -e "${CYAN}WebRTC (low-latency browser):${NC}"
echo "  http://$SERVER_IP:8889/<stream-name>"
echo ""
echo -e "${CYAN}HLS (mobile apps, browsers):${NC}"
echo "  http://$SERVER_IP:8888/<stream-name>/index.m3u8"
echo ""

# Recent logs
echo -e "${BLUE}[Recent Activity]${NC}"
echo "Last 5 log entries:"
journalctl -u mediamtx.service -n 5 --no-pager -o short-precise | sed 's/^/  /'

echo ""
echo "=========================================="
echo "Useful Commands:"
echo "  View live logs:     journalctl -u mediamtx -f"
echo "  Restart service:    sudo systemctl restart mediamtx"
echo "  Edit config:        nano $CONFIG_FILE"
echo "  Add camera:         ./scripts/add-camera-path.sh"
echo "=========================================="
