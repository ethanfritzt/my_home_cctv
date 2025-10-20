#!/bin/bash
# setup-mediamtx-server.sh - Install and configure MediaMTX with Arducam support on Raspberry Pi 5
# This script compiles MediaMTX from source with rpicamera support for Arducam compatibility

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build directory
BUILD_DIR="$HOME/mediamtx-build"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do NOT run this script as root. Run as regular user (pi).${NC}"
    echo "The script will prompt for sudo when needed."
    exit 1
fi

echo "=========================================="
echo "  MediaMTX Server Setup (Arducam)"
echo "  Raspberry Pi 5"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Install build dependencies"
echo "  2. Compile mediamtx-rpicamera for Arducam support"
echo "  3. Build MediaMTX from source with rpicamera integration"
echo "  4. Install MediaMTX binary to /usr/local/bin/"
echo "  5. Configure MediaMTX with example paths"
echo "  6. Set up systemd service for auto-start"
echo ""
read -p "Continue? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

# Step 1: Install dependencies
echo ""
echo -e "${BLUE}[1/6] Installing build dependencies...${NC}"
sudo apt update
sudo apt install -y git golang g++ xxd wget cmake meson pkg-config \
    python3-jinja2 python3-yaml python3-ply libcamera-dev ninja-build

echo -e "${GREEN}✓${NC} Dependencies installed"

# Step 2: Create build directory
echo ""
echo -e "${BLUE}[2/6] Setting up build environment...${NC}"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clean up any previous builds
if [ -d "mediamtx" ]; then
    echo "Removing previous MediaMTX build..."
    rm -rf mediamtx
fi
if [ -d "mediamtx-rpicamera" ]; then
    echo "Removing previous rpicamera build..."
    rm -rf mediamtx-rpicamera
fi

echo -e "${GREEN}✓${NC} Build directory ready: $BUILD_DIR"

# Step 3: Clone and compile mediamtx-rpicamera
echo ""
echo -e "${BLUE}[3/6] Compiling mediamtx-rpicamera (Arducam support)...${NC}"
git clone https://github.com/bluenviron/mediamtx-rpicamera
cd mediamtx-rpicamera

echo "Running meson setup..."
meson setup --wrap-mode=default build

echo "Compiling with ninja..."
DESTDIR=./prefix ninja -C build install

# Verify the binary was created
if [ ! -f "build/mtxrpicam_64" ]; then
    echo -e "${RED}Error: build/mtxrpicam_64 was not created${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} rpicamera compiled successfully"

# Step 4: Clone MediaMTX and integrate rpicamera binary
echo ""
echo -e "${BLUE}[4/6] Building MediaMTX with rpicamera support...${NC}"
cd "$BUILD_DIR"
git clone https://github.com/bluenviron/mediamtx
cd mediamtx

# Create the internal directory structure
mkdir -p internal/staticsources/rpicamera/

# Copy the compiled rpicamera binary (64-bit for Pi 5)
echo "Copying mtxrpicam_64 to MediaMTX internal directory..."
cp ../mediamtx-rpicamera/build/mtxrpicam_64 internal/staticsources/rpicamera/

# Build MediaMTX with Go
echo "Compiling MediaMTX..."
go build -o mediamtx

if [ ! -f "mediamtx" ]; then
    echo -e "${RED}Error: MediaMTX binary was not created${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} MediaMTX compiled successfully"

# Step 5: Install MediaMTX binary
echo ""
echo -e "${BLUE}[5/6] Installing MediaMTX...${NC}"
sudo mv mediamtx /usr/local/bin/mediamtx
sudo chmod +x /usr/local/bin/mediamtx

echo -e "${GREEN}✓${NC} MediaMTX installed to /usr/local/bin/mediamtx"

# Step 6: Configure MediaMTX
echo ""
echo -e "${BLUE}[6/6] Configuring MediaMTX...${NC}"

# Get the project directory (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if config example exists
CONFIG_EXAMPLE="$PROJECT_DIR/mediamtx.yml.example"
CONFIG_DEST="$HOME/mediamtx.yml"

if [ -f "$CONFIG_EXAMPLE" ]; then
    if [ -f "$CONFIG_DEST" ]; then
        echo "Existing mediamtx.yml found. Creating backup..."
        cp "$CONFIG_DEST" "$CONFIG_DEST.backup.$(date +%Y%m%d-%H%M%S)"
        echo -e "${YELLOW}→${NC} Backed up existing configuration"
    fi

    cp "$CONFIG_EXAMPLE" "$CONFIG_DEST"
    echo -e "${GREEN}✓${NC} Configuration file created: $CONFIG_DEST"
else
    echo -e "${YELLOW}⚠${NC}  Warning: mediamtx.yml.example not found"
    echo "    You'll need to create $CONFIG_DEST manually"
fi

# Set up systemd service
SERVICE_EXAMPLE="$PROJECT_DIR/mediamtx.service.example"
SERVICE_FILE="/etc/systemd/system/mediamtx.service"

if [ -f "$SERVICE_EXAMPLE" ]; then
    echo ""
    read -p "Install systemd service for auto-start? (y/n): " INSTALL_SERVICE

    if [[ "$INSTALL_SERVICE" =~ ^[Yy]$ ]]; then
        # Update the service file with correct user and paths
        sudo cp "$SERVICE_EXAMPLE" "$SERVICE_FILE"

        # Replace placeholders with actual values
        sudo sed -i "s|User=pi|User=$USER|g" "$SERVICE_FILE"
        sudo sed -i "s|WorkingDirectory=/home/pi|WorkingDirectory=$HOME|g" "$SERVICE_FILE"
        sudo sed -i "s|/home/pi/mediamtx.yml|$CONFIG_DEST|g" "$SERVICE_FILE"

        sudo systemctl daemon-reload
        echo -e "${GREEN}✓${NC} Systemd service installed"

        read -p "Enable auto-start on boot? (y/n): " ENABLE_SERVICE
        if [[ "$ENABLE_SERVICE" =~ ^[Yy]$ ]]; then
            sudo systemctl enable mediamtx.service
            echo -e "${GREEN}✓${NC} Auto-start enabled"
        fi

        read -p "Start MediaMTX now? (y/n): " START_SERVICE
        if [[ "$START_SERVICE" =~ ^[Yy]$ ]]; then
            sudo systemctl start mediamtx.service
            sleep 2
            sudo systemctl status mediamtx.service --no-pager
        fi
    fi
fi

# Clean up build directory
echo ""
read -p "Remove build directory ($BUILD_DIR)? (y/n): " CLEANUP
if [[ "$CLEANUP" =~ ^[Yy]$ ]]; then
    cd "$HOME"
    rm -rf "$BUILD_DIR"
    echo -e "${GREEN}✓${NC} Build directory removed"
fi

# Final summary
echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "MediaMTX has been installed and configured."
echo ""
echo "Configuration file: $CONFIG_DEST"
echo "Service file: $SERVICE_FILE"
echo ""
echo "Service management:"
echo "  Start:   sudo systemctl start mediamtx"
echo "  Stop:    sudo systemctl stop mediamtx"
echo "  Status:  sudo systemctl status mediamtx"
echo "  Logs:    journalctl -u mediamtx -f"
echo ""
echo "Stream URLs (replace <camera-name> with your stream path):"
echo "  RTSP:    rtsp://viewer:password@<this-pi-ip>:8554/<camera-name>"
echo "  WebRTC:  http://<this-pi-ip>:8889/<camera-name>"
echo "  HLS:     http://<this-pi-ip>:8888/<camera-name>"
echo ""
echo "Next steps:"
echo "  1. Edit $CONFIG_DEST to add camera paths"
echo "  2. Configure camera nodes to publish to this server"
echo "  3. Use $SCRIPT_DIR/add-camera-path.sh to easily add cameras"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
