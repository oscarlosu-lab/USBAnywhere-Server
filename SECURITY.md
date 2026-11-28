# Security Policy — USBAnywhere Server

## Supported Versions

| Version | Supported | Status |
| --- | --- | --- |
| 3.5.0 | Yes | Latest Stable Release |
| 3.4.x | Yes | Active Stable |
| < 3.4 | No | Unsupported |

## Security Model
- **Windows Server**: Firewall rules for USB/IP (`TCP 3240`), discovery/control (`UDP/TCP 3241`), and pinned TLS 1.3 (`TCP 3243`) are restricted to Private/Domain profiles and optional `BindAddress`, with IP whitelist enforcement, `PAIR` 6-digit lockout (5 attempts / 5-min TTL), and `SecurityHelper.IsValidBusId()` input validation.
- **macOS Server**: Uses Apple Userspace `IOKit.framework` / `IOUSBHost` without third-party `.kext` kernel extensions, plus `BindAddress` scoping, optional IP allowlist, and `control_token` verification in `ControlServer.swift`.
- **Linux Server**: `usbanywhere-ctl` restricts remote `PAIR_CREATE` to loopback unless `control_token` is set, persists pairing state with `0o600` permissions, and supports `allowed_ips` and constant-time HMAC `control_token` verification on TCP `3241`.
- **Fail-Closed Updater**: Verifies installer `SHA256SUMS.txt` over HTTPS before execution.

## Reporting a Vulnerability
Please report security vulnerabilities privately via [GitHub Security Advisories](https://github.com/oscarlosu-lab/USBAnywhere-Server/security/advisories/new) instead of opening a public issue.
