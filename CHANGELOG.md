# CHANGELOG - USBAnywhere Server

## [3.3.1] - 2026-11-11

### Fixed
- **Linux `usbanywhere-ctl` Bind/Unbind Race & `SDEV_ST_ERROR` Recovery (Issue #9)**:
  - Added per-`busid` `threading.Lock`, `udevadm settle`, and real `/sys/bus/usb/drivers/usbip-host/<busid>/usbip_status` verification in `share_device()`.
  - Waits for `SDEV_ST_USED` (`2`) / `SDEV_ST_ERROR` (`3`) settlement and automatically unbinds/retries stalled `SDEV_ST_ERROR` devices, fixing re-attach failures after USBIP detach.
- **Raspberry Pi `dwc_otg` Kernel Patch (`patches/rpi-dwc-usbip-host/`, Issue #9)**:
  - Fixed `usbip-host-y` Kbuild objects in `build-patched-usbip-host.sh` (`stub_dev.o stub_main.o stub_rx.o stub_tx.o`, omitting `usbip_common.o`) and regenerated `SHA256SUMS.txt`.
- **macOS Server (`USBAnywhere.Server.Mac`)**:
  - Updated advertised Bonjour/log/UI version metadata to `3.3.1`.

## [3.3.0] - 2026-11-10

### Added
- **Universal Linux Client Mode (`scripts/usbanywhere-ctl` v3.3.0)**:
  - Full client support on Linux (Ubuntu, Debian, Mint, Arch, Fedora, SteamOS, Bazzite) via the kernel `vhci_hcd` virtual host controller.
  - Seamless compatibility with **On-Demand Dynamic Binding (`TCP 3241`)**: `usbanywhere-ctl` automatically queries `LIST` on TCP 3241, dispatches `BIND <busid>` prior to `usbip attach`, and sends `UNBIND <busid>` on `disconnect` to return the peripheral to the remote host.
  - New CLI commands (`scan [subnet]`, `remote <ip>`, `connect <ip> <busid>`, `disconnect [port|all]`, `ports`) and interactive Control Dashboard options (`[9]` Connect Remote Device, `[0]` Disconnect Client Port).

### Fixed
- **DualSense Audio Interface De-Authorization & Raspberry Pi `dwc_otg` Diagnostics (Issue #6)**:
  - Updated `99-usbanywhere-dualsense-fix.rules` to match `ENV{DEVTYPE}=="usb_interface"` using parent `ATTRS{idVendor}=="054c"` and `ATTR{bInterfaceClass}=="01", ATTR{authorized}="0"` for both `0ce6` (DualSense) and `0df2` (DualSense Edge), plus automatic `dwc_otg` warning in `usbanywhere-ctl doctor`.
- **Unix LF Line-Ending Enforcement**:
  - Enforced `eol=lf` via `.gitattributes` across all shell scripts (`*.sh`), `udev` rules (`*.rules`), and `usbanywhere-ctl`.

---

## [3.2.0] - 2026-11-01

### Added
- **Obsidian Precision Design System (Windows & macOS v3.2.0)**:
  - Unified Obsidian Precision palette across Windows WPF (`App.xaml`, `ThemeService.cs`, `MainWindow.xaml`, `SettingsWindow.xaml`) and macOS SwiftUI (`Theme.swift`, `MainView.swift`, `MenuBarView.swift`, `SettingsView.swift`).
  - Added dedicated `AccentForeground`, `DataGridBg`, `DataGridAltBg`, and `AccentButton` styles ensuring WCAG-compliant contrast in both Dark (`#D2F800` lime with `#0B0C0E` text) and Light (`#111827` slate with `#FFFFFF` text) themes.
- **Unified TCP 3241 Dynamic Control Daemon (Windows, Linux, macOS)**:
  - **Windows Server (`DiscoveryResponderService.cs`)**: Added TCP 3241 control listener supporting `LIST`, `BIND <busid>`, `UNBIND <busid>`, and `STATUS` alongside UDP 3241 LAN broadcast discovery.
  - **Linux Server (`scripts/usbanywhere-ctl`)**: Added `/etc/usbanywhere/policy.json` Host Export Policy (`allowlist`/`blocklist`, VID:PID & BusID rules), composite child `bInterfaceClass` inspection, Valve Steam Controller (`28de:*`) detection, and USB Hub filtering.
  - **macOS Server (`ControlServer.swift`, `IOKitDeviceManager.swift`, `URBHandler.swift`)**: Added POSIX TCP 3241 control daemon, shared `/tmp/usbanywhere-mac-state.json` IPC synchronization between CLI and daemon, auto-unbind on client disconnect, and full USB descriptor generation (`0x01`, `0x02`, `0x03`, `0x06`, `0x22`).

### Fixed
- **Fixed Auto-Unbind vs Auto-Bind Loop on Windows & Linux**:
  - Windows Server now tracks devices released by `AutoUnbindOnDisconnect` (`_releasedByAutoUnbindBusIds`) so `AutoBindEnabled` never re-binds a device 2 seconds after client detachment until physical replug or manual share.
  - Linux installer (`install-server-linux.sh`) now purges legacy `usbanywhere-autobind.service` units and normalizes CRLF line endings via `.gitattributes`.
- **Fixed Windows Firewall Rule Scope for Dynamic Control & VPNs**:
  - Updated `FirewallService.cs` to open TCP `3240,3241` and UDP `3241` across `localsubnet`, RFC1918 private ranges, and Tailscale/ZeroTier CGNAT (`100.64.0.0/10`).
- **Fixed macOS CI Build & Bundle Execution**:
  - Updated `.github/workflows/ci.yml` to invoke `.build/release/usbanywhere-server-mac` directly during headless CI verification so `NSApplication` bundle detection does not launch the GUI loop in CLI tests.

---

## [3.1.0] - 2026-10-31

### Added
- **Auto-Unbind on Disconnect (`AutoUnbindOnDisconnect`)**:
  - Automatically unbinds shared USB devices when the remote client disconnects (`Attached` -> `Shared` transition), releasing them back to the host Windows machine's native device stack (XInput/HID/DirectInput).
  - Configurable toggle in Settings UI and persisted in `AppSettings.json`.
- **Linux Dynamic Daemon & Sysfs Auto-Release Synchronization**:
  - Synchronized `scripts/usbanywhere-ctl` and `scripts/install-server-linux.sh` across server repositories.
  - Added sysfs `usbip_status` watcher (releasing devices when remote client detaches) and dynamic control socket on TCP port 3241.

---

## [3.0.1] - 2026-10-26

### Added
- **Native macOS USB/IP Server (src/USBAnywhere.Server.Mac)** 🍏
  - Pure Swift 5.9+ implementation using Apple's Userspace IOKit.framework and IOUSBHostInterface.
  - Universal binary: runs natively on Apple Silicon (**M1, M2, M3, M4**) and Intel (x86_64).
  - Exclusive interface seizure (USBDeviceOpenSeize) without requiring kernel extensions (.kext) or disabling SIP.
  - 1-Click terminal installer (install-server-mac.sh) with persistent launchd LaunchDaemon management.
- **Dual-Job CI Workflow with Live Loopback Integration Testing** 🧪
  - Automated GitHub Actions running on Windows (.NET 9) and macOS 14 (Apple Silicon runner).
  - Live TCP loopback handshake verification (OP_REQ_DEVLIST on port 3240) in CI on macOS Darwin arm64.

### Fixed
- **Hardened Windows Firewall Configuration** 🛡️
  - Firewall rule for port 3240 is now restricted strictly to **Private** and **Domain** network profiles, preventing exposure on untrusted Public networks.
- **Dependency & SDK Alignment** 📦
  - Bumped Microsoft.NET.Test.Sdk to 17.12.0 for .NET 9 compatibility.

---

## [3.0.0] - 2026-10-24

### Added
- **Rebrand & Migration to USBAnywhere Server v3.0.0 (.NET 9.0)** 🌐
  - Migrated entire project from `SnakeUSBIP-Server` (.NET 8.0) to `USBAnywhere-Server` (.NET 9.0) and linked directly with the **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** ecosystem.
- **One-Click "Share All" (`⚡ Share All`)** ⚡
  - Added a dedicated toolbar button to share all eligible local USB devices in a single click.
- **Interactive Server IP Badge & Client Launcher (`🔗 USBAnywhere Client`)** 🔗
  - Displays the active LAN IPv4 address and TCP port (`3240`) in the header (click to copy to clipboard) and launches `USBAnywhere.exe` locally or opens the client release page.
- **Persistent Auto-Bind Device Memory** 🔄
  - Sharing a device automatically registers its `VID:PID` in `AutoBindDevices`, and stopping it removes it, with concurrency protection against overlapping bind calls.

### Fixed
- **Fixed `Attached` and `Shared (forced)` Status Parsing** 🛠️
  - Updated `UsbipdService` regex to capture multi-word states (`Shared (forced)`, `Attached`) and stop before the `Persisted:` section, ensuring the **🚫 Stop** button remains visible for attached and force-shared devices.
- **Fixed Dynamic Theme Switching (`DynamicResource`)** 🎨
  - Removed shadowed `StaticResource` brushes in `MainWindow.xaml` and `SettingsWindow.xaml` so Dark/Light theme switching updates all UI elements immediately.
- **Fixed False Portable Detection in `C:\Program Files`** 📁
  - Updated `PathService` so running as Administrator inside `Program Files` correctly uses `%AppData%\USBAnywhere-Server` unless an explicit `.portable` / `portable.flag` file is present.
- **Fixed CLI Flags (`--minimized`, `--install-driver`) & Startup Preferences** 🚀
  - `MainWindow` now honors `--minimized`, `--install-driver`, `StartMinimized`, `CheckForUpdates`, and persists language selection in `SettingsService`.
- **Fail-Closed SHA-256 Auto-Updater (Setup & Portable)** 🔒
  - `UpdateService` now enforces `SHA256SUMS.txt` verification fail-closed and supports both `.exe` installer and `.zip` portable self-updates.

---
## [2.0.1] - 2026-10-19

### Fixed
- **Atomic Settings Persistence & Path Fix** 💾
- **Flicker-Free UI DataGrid** ⚡
- **Installer Drivers Missing** 📦
- **Safe MSI Uninstaller** 🧹
- **Elevated Windows Startup via Task Scheduler** 🚀
- **Fail-Closed SHA-256 Update Verification** 🛡️
- **Single-Instance Mutex Protection** 🔒
