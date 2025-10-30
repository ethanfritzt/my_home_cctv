#!/bin/bash
# publish-stream.sh - Stream Pi camera to MediaMTX server
# This script captures video using libcamera and streams it via RTSP

# Configuration - These values are set via environment variables by the systemd service
# SERVER_IP and STREAM_NAME should be set in the systemd service file
# They are configured during setup by init-camera-node.sh

# Get current username
CURRENT_USER=$(whoami)

# Video settings
WIDTH=1296
HEIGHT=972
FRAMERATE=15

# These should be set in env
STREAM_NAME=
SERVER_IP=
PORT=

# Log startup
echo "Starting camera stream..."
echo "User: $CURRENT_USER"
echo "Server: $SERVER_IP"
echo "Stream: $STREAM_NAME"
echo "Resolution: ${WIDTH}x${HEIGHT} @ ${FRAMERATE}fps"

# Validate required environment variables
if [ -z "$SERVER_IP" ]; then
    echo "Error: SERVER_IP environment variable is not set"
    exit 1
fi

if [ -z "$STREAM_NAME" ]; then
    echo "Error: STREAM_NAME environment variable is not set"
    exit 1
fi

# Stream to MediaMTX using H.264 hardware encoding (no authentication)
rpicam-vid -t 0 --codec h264 --inline --width $WIDTH --height $HEIGHT --framerate $FRAMERATE -o - \
| ffmpeg -fflags nobuffer -i - -c copy -f rtsp -rtsp_transport tcp "rtsp://$SERVER_IP:$PORT/$STREAM_NAME"                         
