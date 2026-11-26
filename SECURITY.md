# Security Policy — USBAnywhere Server

## Supported Versions

| Version | Supported | Status |
| --- | --- | --- |
| 3.4.0-rc.1 | Yes | Release Candidate (Pre-release) |
| 3.3.x | Yes | Active Stable (Current: v3.3.2) |
| < 3.3 | No | Unsupported |

## Security Model
- **Windows Server**: Firewall rules for USB/IP (`TCP 3240`) and discovery/control (`UDP/TCP 3241`) are restricted to Private/Domain profiles, with optional IP whitelist enforcement (`DiscoveryResponderService.cs`) and `SecurityHelper.IsValidBusId()` input validation.
- **macOS Server**: Uses Apple Userspace `IOKit.framework` without third-party `.kext` kernel extensions, plus optional IP allowlist and `control_token` verification in `ControlServer.swift`.
- **Linux Server**: `usbanywhere-ctl` supports optional `allowed_ips` and constant-time HMAC `control_token` verification (`policy allow-ip|deny-ip|set-token|clear-token`) on TCP `3241`.
- **Fail-Closed Updater**: Verifies installer `SHA256SUMS.txt` over HTTPS before execution.

## Reporting a Vulnerability
Please report security vulnerabilities privately via [GitHub Security Advisories](https://github.com/oscarlosu-lab/USBAnywhere-Server/security/advisories/new) instead of opening a public issue.
