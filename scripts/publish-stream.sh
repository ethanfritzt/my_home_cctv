#!/bin/bash
# publish-stream.sh - Stream Pi Zero camera to MediaMTX using rpicam-vid
# Optimized for low latency and minimal CPU usage
#
# NOTE: This script is now LEGACY - the systemd service calls rpicam-vid directly
# It's kept for backwards compatibility and manual testing
#
# For production use, the camera-stream.service calls rpicam-vid directly
# without this wrapper script

# Configuration - These values are set via environment variables
# SERVER_IP and STREAM_NAME should be set in the systemd service file
# or exported in your shell for manual testing

# Get current username
CURRENT_USER=$(whoami)

# Video settings (optimized for Pi Zero W)
WIDTH=1280
HEIGHT=720
FRAMERATE=25
LEVEL="4.2"

# Log startup
echo "Starting camera stream with rpicam-vid..."
echo "User: $CURRENT_USER"
echo "Server: $SERVER_IP"
echo "Stream: $STREAM_NAME"
echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FRAMERATE}fps"
echo "Profile: H.264 Level $LEVEL"

# Validate required environment variables
if [ -z "$SERVER_IP" ]; then
    echo "Error: SERVER_IP environment variable is not set"
    echo "Usage: SERVER_IP=192.168.1.100 STREAM_NAME=camera ./publish-stream.sh"
    exit 1
fi

if [ -z "$STREAM_NAME" ]; then
    echo "Error: STREAM_NAME environment variable is not set"
    echo "Usage: SERVER_IP=192.168.1.100 STREAM_NAME=camera ./publish-stream.sh"
    exit 1
fi

# Stream directly to MediaMTX using rpicam-vid
# No FFmpeg required - saves CPU and reduces latency
echo "Streaming to: tcp://$SERVER_IP:8554/$STREAM_NAME"

rpicam-vid -t 0 \
    --inline \
    --codec h264 \
    --width $WIDTH \
    --height $HEIGHT \
    --framerate $FRAMERATE \
    --level $LEVEL \
    --low-latency \
    --output "tcp://$SERVER_IP:8554/$STREAM_NAME"
