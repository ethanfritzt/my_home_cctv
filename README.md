# Raspberry Pi Home Security Camera System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A production-ready **24/7 home security camera system** using Raspberry Pi Zero W nodes with Arducam OV5647 modules, streaming to a central Raspberry Pi 5 server running MediaMTX. Features H.264 hardware encoding, low latency streaming, and support for multiple concurrent viewers.

## Features

- **Low Latency Streaming**: Real-time H.264 hardware encoding via libcamera
- **Scalable Architecture**: Support for multiple camera nodes streaming to a central server
- **Multiple Protocols**: RTSP, WebRTC, and HLS streaming support
- **Auto-Recovery**: Systemd services with automatic restart on failure
- **Secure**: Password-protected streams with separate publish/read credentials
- **Resource Efficient**: Optimized for 24/7 operation on low-power hardware

---

## Table of Contents

- [Hardware Requirements](#hardware-requirements)
- [Software Requirements](#software-requirements)
- [Quick Start](#quick-start)
- [Installation](#installation)
  - [Camera Node Setup](#camera-node-setup)
  - [Central Server Setup](#central-server-setup)
- [Deployment](#deployment)
- [Hardware Installation](#hardware-installation)
- [Monitoring and Maintenance](#monitoring-and-maintenance)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Contributing](#contributing)
- [License](#license)
- [References](#references)

---

## Hardware Requirements

### Camera Node (Per Camera)

| Component | Specification |
|-----------|---------------|
| Single Board Computer | Raspberry Pi Zero W or WH |
| Camera Module | Arducam OV5647 (CSI interface) |
| Storage | MicroSD card (8GB minimum, 16GB+ recommended) |
| Power Supply | 5V 2A USB power adapter |
| Network | 2.4 GHz Wi-Fi (strong signal required) |

### Central Server

| Component | Specification |
|-----------|---------------|
| Single Board Computer | Raspberry Pi 5 (4GB RAM recommended) |
| Storage | MicroSD card (16GB minimum) or SSD |
| Power Supply | 5V 3A USB-C power adapter |
| Network | Ethernet connection (recommended) or 5GHz Wi-Fi |

### Optional Components

- Ethernet switch for wired camera connections
- 3D printed camera enclosures
- PoE HATs for network-powered cameras
- UPS for continuous operation during power outages

---

## Software Requirements

### Camera Node

- **Operating System**: Raspberry Pi OS Lite (latest)
- **Core Dependencies**:
  - `libcamera` (custom compiled for Arducam compatibility)
  - `ffmpeg`
  - `systemd`

### Central Server

- **Operating System**: Raspberry Pi OS or Ubuntu for Raspberry Pi
- **Streaming Server**: MediaMTX (compiled from source with Arducam support)
- **Optional**: Home Assistant, VLC, NVR software for recording

---

## Quick Start

```bash
# On Camera Node (Pi Zero W)
sudo apt update && sudo apt install -y ffmpeg git
# Follow camera node setup below

# On Central Server (Pi 5)
# Follow central server setup below

# Test stream
# RTSP: rtsp://<pi5-ip>:8554/cam-zero1
# WebRTC: http://<pi5-ip>:8889/cam-zero1
```

---

## Installation

### Camera Node Setup

#### 1. Install Dependencies

```bash
sudo apt update && sudo apt install -y ffmpeg git g++ xxd wget cmake meson pkg-config python3-jinja2 python3-yaml python3-ply libcamera-dev
```

#### 2. Compile libcamera for Arducam

Custom libcamera compilation ensures full compatibility with Arducam OV5647 modules.

```bash
git clone https://github.com/bluenviron/mediamtx-rpicamera
cd mediamtx-rpicamera
meson setup --wrap-mode=default build && DESTDIR=./prefix ninja -C build install
```

This produces `build/mtxrpicam_32` (32-bit) or `build/mtxrpicam_64` (64-bit).

#### 3. Enable Camera Interface

```bash
sudo raspi-config
# Navigate to: Interface Options → Camera → Enable
sudo reboot
```

#### 4. Test Camera

```bash
libcamera-hello
```

You should see a preview window (or confirmation if running headless).

#### 5. Create Streaming Script

Create `/home/pi/camera-stream.sh`:

```bash
#!/bin/bash
# camera-stream.sh - Stream Pi Zero camera to MediaMTX server

# Configuration
SERVER_IP="192.168.1.100"    # Replace with your Pi 5 IP
STREAM_NAME="cam-zero1"      # Unique name for this camera
USER="zero1"                 # Publisher username
PASS="camera"                # Publisher password

# Stream to MediaMTX using H.264 hardware encoding
libcamera-vid -t 0 \
    --codec h264 \
    --inline \
    --width 1280 --height 720 \
    --framerate 15 \
    -o - \
| ffmpeg -re -i - -c copy -f rtsp "rtsp://$USER:$PASS@$SERVER_IP:8554/$STREAM_NAME"
```

Make executable:

```bash
chmod +x /home/pi/camera-stream.sh
```

---

### Central Server Setup

#### 1. Install Build Dependencies

```bash
sudo apt update && sudo apt install -y git golang g++ xxd wget cmake meson pkg-config python3-jinja2 python3-yaml python3-ply
```

#### 2. Compile MediaMTX with Arducam Support

```bash
# Clone MediaMTX
git clone https://github.com/bluenviron/mediamtx
cd mediamtx

# Clone and compile rpicamera support
git clone https://github.com/bluenviron/mediamtx-rpicamera
cd mediamtx-rpicamera
meson setup --wrap-mode=default build && DESTDIR=./prefix ninja -C build install

# Copy binary (use 64-bit for Pi 5)
mkdir -p ../internal/staticsources/rpicamera/
cp build/mtxrpicam_64 ../internal/staticsources/rpicamera/

# Build MediaMTX
cd ..
go build -o mediamtx
sudo mv mediamtx /usr/local/bin/
```

#### 3. Configure MediaMTX

Create `mediamtx.yml`:

```yaml
###############################################
# MediaMTX Configuration
###############################################

# RTSP server
rtspAddress: :8554

# HLS server
hlsAddress: :8888
hls: yes

# WebRTC server
webrtcAddress: :8889
webrtc: yes

# Path configuration
paths:
  # Camera 1
  cam-zero1:
    publishUser: zero1
    publishPass: camera

  # Camera 2
  cam-zero2:
    publishUser: zero2
    publishPass: camera

  # Global read access
  all:
    readUser: viewer
    readPass: password
```

#### 4. Create Systemd Service

Create `/etc/systemd/system/mediamtx.service`:

```ini
[Unit]
Description=MediaMTX RTSP Server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi
ExecStart=/usr/local/bin/mediamtx /home/pi/mediamtx.yml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mediamtx.service
sudo systemctl start mediamtx.service
```

#### 5. Access Streams

| Protocol | URL Format | Use Case |
|----------|-----------|----------|
| **RTSP** | `rtsp://viewer:password@<pi5-ip>:8554/cam-zero1` | VLC, NVR software |
| **WebRTC** | `http://<pi5-ip>:8889/cam-zero1` | Low-latency browser viewing |
| **HLS** | `http://<pi5-ip>:8888/cam-zero1` | Mobile apps, broad compatibility |

---

## Deployment

### Systemd Service for Camera Nodes

Create `/etc/systemd/system/camera-stream.service` on each Pi Zero:

```ini
[Unit]
Description=Camera Stream to MediaMTX
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pi
ExecStart=/home/pi/camera-stream.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable camera-stream.service
sudo systemctl start camera-stream.service
```

---

## Hardware Installation

### 3D Printed Enclosure

- Use a ventilated enclosure designed for Pi Zero W
- Ensure camera lens has an unobstructed view
- Include cable management for power and optional antenna extension
- Mount securely to prevent vibration affecting image quality

### Power and Network

- **Static IP Assignment**: Configure DHCP reservations for each Pi Zero node
- **Power Supply**: Use quality 5V 2A adapters; avoid underpowered USB ports
- **Wi-Fi Optimization**:
  - Position cameras within strong signal range
  - Use 2.4 GHz (better range) for camera nodes
  - Consider Wi-Fi extenders for distant locations

---

## Monitoring and Maintenance

### Check Service Status

**Camera Node:**
```bash
sudo systemctl status camera-stream.service
```

**Central Server:**
```bash
sudo systemctl status mediamtx.service
```

### View Live Logs

**Camera Node:**
```bash
journalctl -u camera-stream.service -f
```

**Central Server:**
```bash
journalctl -u mediamtx.service -f
```

### Performance Monitoring

```bash
# CPU and memory usage
htop

# Network bandwidth
iftop

# Temperature monitoring
vcgencmd measure_temp
```

---

## Troubleshooting

### Camera Not Detected

```bash
# Verify camera is connected
libcamera-hello

# Check CSI cable connection
# Ensure camera is enabled in raspi-config
```

### Stream Connection Failed

```bash
# Verify MediaMTX is running
systemctl status mediamtx.service

# Check network connectivity
ping <server-ip>

# Verify credentials in camera-stream.sh match mediamtx.yml
```

### High CPU Usage

- Reduce resolution or framerate in camera-stream.sh
- Ensure H.264 hardware encoding is enabled
- Check for multiple streaming processes

### Network Lag

- Use wired Ethernet instead of Wi-Fi where possible
- Reduce framerate to 10-12 fps
- Ensure proper bandwidth allocation

---

## Best Practices

### Performance Optimization

- **Resolution**: Use 720p (1280x720) for Pi Zero W nodes
- **Framerate**: 15 fps provides smooth video with low CPU load
- **Encoding**: Always use H.264 hardware encoding
- **Bitrate**: Let libcamera auto-adjust based on scene complexity

### Security Recommendations

- Change default passwords in `mediamtx.yml`
- Use separate credentials for publish and read access
- Consider VPN access for remote viewing
- Keep systems updated with security patches

### Reliability

- Enable automatic restarts via systemd
- Monitor system logs regularly
- Use quality SD cards (Class 10, A1 rated)
- Implement UPS for critical installations

### Scaling

- Add cameras by duplicating the stream script with new names
- Pi 5 can handle 4-6 simultaneous 720p streams
- Consider multiple Pi 5 servers for larger installations
- Use network switches to segment camera traffic

---

## Contributing

Contributions are welcome! Please feel free to submit issues, fork the repository, and create pull requests for any improvements.

### Development Setup

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## References

### Official Documentation

- [MediaMTX GitHub Repository](https://github.com/bluenviron/mediamtx)
- [Arducam Documentation](https://www.arducam.com)
- [Raspberry Pi Camera Documentation](https://www.raspberrypi.com/documentation/computers/camera_software.html)
- [libcamera Project](https://libcamera.org/)

### Community Resources

- [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)
- [MediaMTX Discussions](https://github.com/bluenviron/mediamtx/discussions)

### Related Projects

- [MotionEye](https://github.com/ccrisan/motioneye) - Alternative camera surveillance system
- [Shinobi](https://shinobi.video/) - Open-source CCTV solution
- [ZoneMinder](https://zoneminder.com/) - Full-featured video surveillance system

---

**Built with** Raspberry Pi, Arducam, MediaMTX, and libcamera

Made with dedication for home security enthusiasts
