# Raspberry Pi Zero W Arducam Home Security Camera System

This project sets up a **24/7 home security camera system** using Raspberry Pi Zero W nodes with Arducam OV5647 modules, streaming to a **central Raspberry Pi 5 server** running **MediaMTX**. Each camera node streams via **H.264 hardware encoding** using `libcamera` + `ffmpeg`, while the Pi 5 aggregates and re-streams to multiple clients.

---

## Table of Contents

- [Hardware Requirements](#hardware-requirements)  
- [Software Requirements](#software-requirements)  
- [Project Setup](#project-setup)  
  - [Pi Zero W Camera Node](#pi-zero-w-camera-node)  
  - [Pi 5 Central MediaMTX Server](#pi-5-central-mediamtx-server)  
- [Deployment](#deployment)  
  - [Systemd Service for 24/7 Streaming](#systemd-service-for-247-streaming)  
  - [Starting & Monitoring](#starting--monitoring)  
- [Hardware Installation](#hardware-installation)  
  - [3D Printed Enclosure](#3d-printed-enclosure)  
  - [Power and Network](#power-and-network)  
- [Notes & Best Practices](#notes--best-practices)  
- [References](#references)  

---

## Hardware Requirements

### Camera Node (Pi Zero W)

- Raspberry Pi Zero W or WH  
- Arducam OV5647 camera module (CSI)  
- MicroSD card (8–32GB, Raspbian Lite recommended)  
- 5V 2A power supply  
- Optional: Wi-Fi extender or strong 2.4 GHz Wi-Fi  

### Central Server (Pi 5)

- Raspberry Pi 5 (4GB recommended)  
- MicroSD card or external SSD for storage  
- 5V 3A power supply  
- Wired or strong Wi-Fi connection  

### Optional

- Ethernet switch for stable LAN  
- 3D printed camera enclosure  

---

## Software Requirements

### Pi Zero W

- Raspberry Pi OS Lite  
- `libcamera` (pre-installed on modern OS)  
- `ffmpeg`  
- `systemd` (for auto-starting stream)

```bash
sudo apt update && sudo apt install -y ffmpeg git
````

### Pi 5

* Raspberry Pi OS / Ubuntu for Pi
* MediaMTX precompiled or compiled from source
* Optional: Home Assistant, VLC, NVR software

---

## Project Setup

### Pi Zero W Camera Node

1. Enable the camera:

```bash
sudo raspi-config
# Interface Options → Camera → Enable
```

2. Test camera:

```bash
libcamera-hello
```

3. Create a streaming script: `/home/pi/camera-stream.sh`

```bash
#!/bin/bash
# camera-stream.sh
# Streams Pi Zero OV5647 to central MediaMTX server

# Replace these values
SERVER_IP="192.168.1.100"   # Pi 5 IP
STREAM_NAME="cam-zero1"
USER="zero1"
PASS="camera"

# Capture and push H.264 to MediaMTX
libcamera-vid -t 0 \
    --codec h264 \
    --inline \
    --width 1280 --height 720 \
    --framerate 15 \
    -o - \
| ffmpeg -re -i - -c copy -f rtsp "rtsp://$USER:$PASS@$SERVER_IP:8554/$STREAM_NAME"
```

Make it executable:

```bash
chmod +x /home/pi/camera-stream.sh
```

---

### Pi 5 Central MediaMTX Server

1. Download precompiled MediaMTX:

```bash
wget https://github.com/bluenviron/mediamtx/releases/latest/download/mediamtx_linux_arm64.tar.gz
tar -xzf mediamtx_linux_arm64.tar.gz
sudo mv mediamtx /usr/local/bin/
```

2. Configure `mediamtx.yml`:

```yaml
paths:
  cam-zero1:
    publishUser: zero1
    publishPass: camera
  cam-zero2:
    publishUser: zero2
    publishPass: camera
  all:
    readUser: viewer
    readPass: password
webrtc: yes
hls: yes
```

3. Start server:

```bash
mediamtx mediamtx.yml
```

* RTSP streams: `rtsp://<Pi5_IP>:8554/cam-zero1`
* WebRTC browser access: `http://<Pi5_IP>:8889/cam-zero1`

---

## Deployment

### Systemd Service for 24/7 Streaming

Create `/etc/systemd/system/camera-stream.service` on each Pi Zero:

```ini
[Unit]
Description=Pi Zero Camera Stream
After=network.target

[Service]
ExecStart=/home/pi/camera-stream.sh
Restart=always
RestartSec=5
User=pi
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

### Starting & Monitoring

* Check status:

```bash
sudo systemctl status camera-stream.service
```

* Follow logs:

```bash
journalctl -u camera-stream.service -f
```

---

## Hardware Installation

### 3D Printed Enclosure

* Use a lightweight 3D printed case for Pi Zero + Arducam.
* Ensure proper **ventilation** for the Pi Zero.
* Mount camera module lens with unobstructed view.
* Include cable management for power and optional Wi-Fi antenna.

### Power and Network

* Use a **stable 5V 2A power supply** for Pi Zero.
* Prefer **static IP** or DHCP reservation for each Pi Zero.
* Position near strong Wi-Fi; avoid long cables or interference.

---

## Notes & Best Practices

* Use **720p @ 15fps** for Pi Zero W nodes for reliable 24/7 streaming.
* Use **H.264 hardware encoding only** to minimize CPU load.
* Logs are critical for monitoring; systemd auto-restart ensures resilience.
* Pi 5 aggregates multiple streams, handles multiple viewers, and can optionally record.
* Add more Pi Zero cameras by copying the script/service and changing `STREAM_NAME` and authentication.

---

## References

* [MediaMTX GitHub](https://github.com/bluenviron/mediamtx)
* [Arducam OV5647](https://www.arducam.com)
* [libcamera Documentation](https://www.raspberrypi.com/documentation/computers/camera_software.html)
* [Raspberry Pi Forums](https://www.raspberrypi.org/forums/)

---

**Congratulations!** You now have a **fully automated, always-on home security camera system** using Raspberry Pi Zero W nodes and a Pi 5 central server.

```

---

This is **complete Markdown**, fully structured with headings, code blocks, and instructions for hardware, software, deployment, and enclosures.  

I can also create a **ready-to-deploy folder structure** with scripts for multiple Pi Zero cameras if you want — it would be plug-and-play.  

Do you want me to do that next?
```
