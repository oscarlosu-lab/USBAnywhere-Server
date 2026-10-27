# USBAnywhere Server - User Manual

🌐 **Language:** English | [Español](USAGE_ES.md)

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [First Run](#first-run)
4. [Sharing USB Devices](#sharing-usb-devices)
5. [Connecting from Client](#connecting-from-client)
6. [Troubleshooting](#troubleshooting)
7. [Uninstallation](#uninstallation)

---

## Introduction

**USBAnywhere Server** allows you to share USB devices connected to your Windows PC over the network. Other computers running **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** can then connect to these devices as if they were plugged in locally.

### Use Cases

- **3D Printers & Laser Engravers**: Share your printer or controller from any PC
- **License Dongles**: Share software protection keys over LAN
- **Scanners & Webcams**: Use from any workstation
- **Serial/UART & Development Boards (CH340, Arduino, ESP32)**: Flash and debug remotely

---

## Installation

### Requirements
- Windows 10/11 (64-bit)
- Administrator privileges
- Local network connection (TCP Port 3240)

### Steps

1. Download the latest release from [GitHub Releases](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest)
2. Run `USBAnywhere-Server_Setup_v3.0.0.exe` or extract `USBAnywhere-Server-v3.0.0-x64-Portable.zip`

---

## First Run

1. Launch `USBAnywhere-Server.exe` (requests Administrator privileges automatically)
2. If `usbipd-win` is not installed, the application will detect the missing driver and install it from the bundled MSI automatically.

---

## Sharing USB Devices

### Share a Single Device or Share All

1. Click **📤 Share** next to any USB device, or click **⚡ Share All** in the top toolbar to share all eligible devices at once.
2. Status changes to `Shared` (or `Attached` when a client connects).
3. Click the green **IP badge** (`IP: x.x.x.x:3240`) in the header to copy the server's IP address to your clipboard.

### Stop Sharing

1. Click **🚫 Stop** on any shared or attached device to return it to local-only access.

---

## Connecting from Client

### Using USBAnywhere Client (Recommended)

1. Download **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere/releases/latest)** (or click **🔗 USBAnywhere Client** in the server toolbar)
2. Paste your server's IP address
3. Click **Scan** and connect to your shared USB devices!

---

## Troubleshooting

See [Troubleshooting Guide](TROUBLESHOOTING.md) or click **⚙️ Settings → 🛡️ Configure Firewall** to open TCP port 3240 in Windows Defender Firewall.

---

## Uninstallation

1. Open **USBAnywhere Server**
2. Click **🗑️ Uninstall Driver** if you wish to remove the `usbipd-win` system driver
3. Use Windows Installed Apps to uninstall **USBAnywhere Server** (or delete the folder if using Portable mode)
