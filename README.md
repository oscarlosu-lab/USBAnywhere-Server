# 🌐 USBAnywhere Server — Desktop USB/IP Server (Windows & macOS)

🌐 **Language / Idioma:** **English** | [Español](README_ES.md)

**v3.1.0** | [🌍 Official Website](https://oscarlosu-lab.github.io/USBAnywhere/) | [📦 Releases & Downloads](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest) | [🔗 USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere) | [📱 USBAnywhere Android](https://github.com/oscarlosu-lab/USBAnywhere-Android) | [💬 Reddit Community](https://www.reddit.com/r/UsbAnywhere/) | [📖 Windows Manual](docs/USAGE_EN.md) | [🍎 macOS Manual](docs/USAGE_MACOS_EN.md) | [🛠️ Troubleshooting](docs/TROUBLESHOOTING.md)

**Share local USB peripherals from Windows PCs and Apple Macs over your network — Zero hassle.**

A unified desktop server suite combining:
- **Windows**: Modern .NET 9.0 WPF GUI server wrapping [usbipd-win](https://github.com/dorssel/usbipd-win).
- **macOS**: Native Swift daemon & CLI tool using userspace IOKit with Universal binary support (Apple Silicon M1/M2/M3/M4 & Intel).

Part of the **[USBAnywhere v3.0+ Open-Source Ecosystem](https://github.com/oscarlosu-lab/USBAnywhere)**.

[![GitHub Downloads](https://img.shields.io/github/downloads/oscarlosu-lab/USBAnywhere-Downloads/total?style=flat-square&logo=github&color=blue)](https://github.com/oscarlosu-lab/USBAnywhere-Downloads/releases/tag/server-v3.1.0)
[![GitHub Stars](https://img.shields.io/github/stars/oscarlosu-lab/USBAnywhere-Server?style=flat-square&logo=github&color=yellow)](https://github.com/oscarlosu-lab/USBAnywhere-Server/stargazers)
[![License](https://img.shields.io/badge/License-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform Windows](https://img.shields.io/badge/platform-Windows%2010%2F11%20(x64)-lightgrey?style=flat-square&logo=windows)](https://github.com/oscarlosu-lab/USBAnywhere-Server)
[![Platform macOS](https://img.shields.io/badge/platform-macOS%20(Apple%20Silicon%20%2F%20Intel)-lightgrey?style=flat-square&logo=apple)](docs/USAGE_MACOS_EN.md)
[![Website](https://img.shields.io/badge/Website-USBAnywhere-06B6D4?style=flat-square&logo=googlechrome&logoColor=white)](https://oscarlosu-lab.github.io/USBAnywhere/)
[![Reddit Community](https://img.shields.io/badge/Reddit-r%2FUsbAnywhere-FF4500?style=flat-square&logo=reddit&logoColor=white)](https://www.reddit.com/r/UsbAnywhere/)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Project-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

---

## ✨ Features

- 🖥️ **Windows & 🍎 macOS Server Support** — Share devices from either Windows or Mac across your LAN, Wi-Fi, or VPN.
- 📡 **Multi-Tier Auto-Discovery** — Native UDP 3241 discovery responder and mDNS Zeroconf service advertising so clients find servers in milliseconds.
- 🎮 **Perfect for Joysticks, SimRacing & Gaming** — Forward flight sticks, racing wheels, gamepads, DACs, and serial adapters with minimal latency.
- 🔧 **Zero Configuration on Windows** — Auto-installs official `usbipd-win` drivers on first run.
- ⚡ **1-Click Auto-Setup on macOS** — Automated curl/bash script sets up universal Swift daemon with LaunchDaemon persistence.
- 📤 **One-Click & Share All** — Instant Share/Stop toggles or **⚡ Share All** for all local USB peripherals.
- 🔄 **Persistent Auto-Bind** — Automatically re-shares remembered devices when plugged back in.
- 🛡️ **Hardened Firewall & Security** — Windows Firewall rules restricted to local subnet; secure daemon privileges.
- 🎨 **Dynamic Dark & Light Themes (Windows)** — Instant runtime theme and ES/EN language switching.

---

## 🚀 Quick Start — Windows Server

1. Download `USBAnywhere-Server_Setup_v3.1.0.exe` or the portable ZIP from [USBAnywhere Downloads](https://github.com/oscarlosu-lab/USBAnywhere-Downloads/releases/tag/server-v3.1.0).
2. Run `USBAnywhere-Server.exe` as Administrator.
3. Click **📤 Share** on any device (or **⚡ Share All**).
4. Click the green **IP badge** in the header to copy your server IP address.
5. In **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** on another Windows PC, enter the IP and click **Connect**!

---

## 🍎 Quick Start — macOS Server

On your Mac (Apple Silicon or Intel), open **Terminal** and run:

```bash
curl -fsSL https://raw.githubusercontent.com/oscarlosu-lab/USBAnywhere-Server/main/scripts/install-server-mac.sh | sudo bash
```

To list connected devices and check export status:
```bash
usbanywhere-server-mac list
```

See [macOS User Guide (English)](docs/USAGE_MACOS_EN.md) / [Guía de macOS (Español)](docs/USAGE_MACOS_ES.md) for full options.

---

## 🐧 Quick Start — Linux Server (Debian/Ubuntu/Raspberry Pi)

On your Linux machine or Raspberry Pi, open **Terminal** and run:

```bash
curl -fsSL https://raw.githubusercontent.com/oscarlosu-lab/USBAnywhere-Server/main/scripts/install-server-linux.sh | sudo bash
```

---

## 🎛️ USBAnywhere Control Suite (`usbanywhere-ctl`)

Both macOS and Linux installations include the **USBAnywhere Control Suite** (`usbanywhere-ctl`), a unified, zero-dependency interactive TUI dashboard and CLI management tool:

```bash
# Launch interactive TUI Control Dashboard:
usbanywhere-ctl

# Run complete system health check:
usbanywhere-ctl doctor

# Run binary USB/IP protocol loopback self-test:
usbanywhere-ctl test

# Service management:
usbanywhere-ctl status
sudo usbanywhere-ctl start
sudo usbanywhere-ctl stop
sudo usbanywhere-ctl restart

# Device inventory & binding:
usbanywhere-ctl list
sudo usbanywhere-ctl share 1-1
sudo usbanywhere-ctl unshare 1-1

# View live colorized daemon logs:
usbanywhere-ctl logs
```

---

## 🔗 USBAnywhere Ecosystem

| Component | Platform / Role | Description |
|---|---|---|
| **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** | 🖥️ Windows 10/11 (x64 / ARM64) | Connect to remote USB devices with WHQL drivers & WSK engine |
| **[USBAnywhere Server](https://github.com/oscarlosu-lab/USBAnywhere-Server)** | 🌐 Windows & 🍎 macOS | Desktop USB/IP server with GUI (Windows) & Swift daemon (macOS) |
| **[USBAnywhere Android](https://github.com/oscarlosu-lab/USBAnywhere-Android)** | 📱 Android & Android TV | Rootless USB/IP server, Sunshine handoff & DualSense haptics |
| **[Linux Server Script](https://github.com/oscarlosu-lab/USBAnywhere/blob/main/scripts/install-server.sh)** | 🐧 Linux & Raspberry Pi | 1-Click kernel USB/IP server auto-bind daemon |
| **[Official Website](https://oscarlosu-lab.github.io/USBAnywhere/)** | 🌍 Web Portal | Interactive guides, documentation & download hub |
| **[Reddit Community](https://www.reddit.com/r/UsbAnywhere/)** | 💬 r/UsbAnywhere | Support, discussions, community setups & announcements |
| **[Support on Ko-fi](https://ko-fi.com/oscarlosu)** | ☕ Community | Support hosting, driver testing & open-source engineering |

## ⚙️ Requirements

- **Windows**: Windows 10/11 (x64), Administrator privileges, TCP port 3240.
- **macOS**: macOS 12 Monterey or newer (Apple Silicon M1/M2/M3/M4 or Intel x86_64), TCP port 3240.

## 📄 License

This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.

See [LICENSE](LICENSE) for full legal terms and conditions.

---

Developed by [oscarlosu-lab](https://github.com/oscarlosu-lab)
