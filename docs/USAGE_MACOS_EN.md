# 🍎 USBAnywhere Server for macOS — User Guide

English | [Español](USAGE_MACOS_ES.md)

---

## Overview

**USBAnywhere Server for macOS** allows your Mac (Apple Silicon M1/M2/M3/M4 or Intel) to share local physical USB devices (such as **flight sticks, simracing wheels, gamepads/joysticks, MIDI instruments, webcams, serial adapters, or dongles**) over the network to any Windows PC running the **USBAnywhere Client**.

It acts as a native USB/IP server listening on standard TCP port `3240`.

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Project-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

---

## ⚡ 1-Click Quick Install

Open **Terminal** on your Mac and run:

```bash
curl -fsSL https://raw.githubusercontent.com/oscarlosu-lab/USBAnywhere-Server/main/scripts/install-server-mac.sh | sudo bash
```

The installer will:
1. Detect your hardware architecture (`arm64` Apple Silicon or `x86_64` Intel).
2. Install the universal binary to `/usr/local/bin/usbanywhere-server-mac`.
3. Configure and activate `/Library/LaunchDaemons/com.usbanywhere.server.plist` to run automatically at boot.
4. Auto-export non-hub USB peripherals.

---

## 🚀 Usage

### 1. View Connected USB Devices
To list connected hardware and their assigned USB bus IDs:

```bash
usbanywhere-server-mac list
```

Example output:
```text
Discovered USB Devices:
  [1-1] Logitech Inc. - Extreme 3D Pro (046D:C215) - 🟡 SHARED
  [1-2] Sony Interactive - DualSense Wireless Controller (054C:0CE6) - 🟡 SHARED
```

### 2. Manual Bind / Unbind
If you do not want to share all devices automatically:

```bash
# Bind specific device:
usbanywhere-server-mac bind 1-1

# Unbind device:
usbanywhere-server-mac unbind 1-1
```

### 3. Connect from Windows PC
1. Open **USBAnywhere Client** on your Windows PC.
2. Enter your Mac's IP address (e.g. `192.168.1.50`).
3. Click **List Devices** (or press **Enter**).
4. Select your joystick/controller and click **Connect**.
5. Windows will recognize the device natively through its standard kernel PnP drivers!

---

## 🔧 Managing Background Service

### Check Service Status
```bash
sudo launchctl list | grep com.usbanywhere.server
```

### View Live Logs
```bash
tail -f /var/log/usbanywhere-server.log
```

### Stop Service
```bash
sudo launchctl unload -w /Library/LaunchDaemons/com.usbanywhere.server.plist
```

### Start Service
```bash
sudo launchctl load -w /Library/LaunchDaemons/com.usbanywhere.server.plist
```

### Uninstall
```bash
sudo usbanywhere-server-mac uninstall-service
```
Or run the uninstall script:
```bash
curl -fsSL https://raw.githubusercontent.com/oscarlosu-lab/USBAnywhere-Server/main/scripts/uninstall-server-mac.sh | sudo bash
```

---

## 🛠️ Building from Source

Requirements:
- macOS 12 Monterey or newer
- Swift 5.9+ / Xcode Command Line Tools (`xcode-select --install`)

```bash
cd src/USBAnywhere.Server.Mac
swift build -c release
cp .build/release/usbanywhere-server-mac /usr/local/bin/
```
