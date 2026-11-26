# Troubleshooting Guide — USBAnywhere Server

🌐 **Language / Idioma:** **English** | [Español](TROUBLESHOOTING_ES.md)

---

## Common Issues

### 1. Application won't start

**Solutions**:
1. Right-click `USBAnywhere-Server.exe` → **Run as administrator**
2. Check Windows Event Viewer or `%AppData%\USBAnywhere-Server\logs` (or `logs\` in Portable mode)

---

### 2. Driver installation fails

**Solutions**:
1. Restart Windows if a Windows Update is pending
2. Manual install: `msiexec /i drivers\usbipd-win.msi` from an Administrator prompt

---

### 3. Client can't see or connect to the server

**Solutions**:
1. Open **⚙️ Settings** in USBAnywhere Server and click **🛡️ Configure Firewall** to open both TCP port 3240 (USB/IP) and UDP port 3241 (Auto-Scan Discovery)
2. Or run in Administrator PowerShell:
   ```powershell
   New-NetFirewallRule -DisplayName "USBAnywhere Server (TCP 3240)" -Direction Inbound -Protocol TCP -LocalPort 3240 -Action Allow
   New-NetFirewallRule -DisplayName "USBAnywhere Discovery (UDP 3241)" -Direction Inbound -Protocol UDP -LocalPort 3241 -Action Allow
   ```
3. Verify the device shows `Shared` status in USBAnywhere Server

---

### 4. `dotnet test` exits with `0xC0000142` (`STATUS_DLL_INIT_FAILED`)

**Symptoms**:
Running `dotnet test` fails immediately with `Test host process exited with error` without executing test cases, and `testhost.exe` exits with `-1073741502` (`0xC0000142`).

**Cause**:
Windows Mandatory Integrity Control (MIC) or inherited NTFS restrictions (`Low Integrity Level` / residual Deny ACEs) prevent the Windows PE loader from initializing runtime DLLs within the test directory.

**Solutions**:
1. Remove any recursive `Deny` rules on the working directory:
   ```cmd
   icacls <project_dir> /remove:d Everyone /t /c
   ```
2. Reset directory integrity level to `Medium`:
   ```cmd
   icacls <project_dir> /setintegritylevel (OI)(CI)M /t /c
   ```
3. Clean build caches and re-run tests:
   ```powershell
   dotnet clean
   dotnet test
   ```

---

### 5. TCP `3241` returns `DENIED` (IP Allowlist / Control Token)

**Symptoms**:
Remote clients receive `{"status": "DENIED"}` or empty device lists when querying TCP `3241`.

**Solutions**:
1. On Linux/macOS, inspect your active policy:
   ```bash
   sudo usbanywhere-ctl policy show
   ```
2. Add the client IP (`sudo usbanywhere-ctl policy allow-ip <client-ip>`) or clear the control token (`sudo usbanywhere-ctl policy clear-token`).
3. On Windows Server, verify your allowed client IPs in **⚙️ Settings** (`DiscoveryResponderService` IP whitelist).

---

### 6. External SSD / USB Storage fails to attach (`uas` driver)

**Symptoms**:
High-speed external SSDs bound to the Linux `uas` (USB Attached SCSI) kernel driver fail to enumerate on the remote client.

**Solutions**:
- `usbanywhere-ctl` and `USBIPServer.swift` detect `uas` drives and warn before binding. Standard `usb-storage` mode (e.g., via `usb-storage.quirks=<vid>:<pid>:u`) provides higher compatibility over USB/IP.

---

### 7. Linux device stuck after client disconnect (`SDEV_ST_ERROR`)

**Solutions**:
1. Run `sudo usbanywhere-ctl doctor` to inspect kernel modules (`usbip_core`, `usbip_host`) and active device states.
2. Restart the dynamic daemon (`sudo usbanywhere-ctl restart`) or apply the `patches/rpi-dwc-usbip-host/` kernel patches on Raspberry Pi / ARM SBCs.

---

## Getting Help

- [USBAnywhere Server Issues](https://github.com/oscarlosu-lab/USBAnywhere-Server/issues)
- [USBAnywhere Client Repository](https://github.com/oscarlosu-lab/USBAnywhere)
- [Reddit Community](https://reddit.com/r/UsbAnywhere)
