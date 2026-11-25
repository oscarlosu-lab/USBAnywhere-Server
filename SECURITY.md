# Security Policy — USBAnywhere Server

## Supported Versions

| Version | Supported | Status |
| --- | --- | --- |
| 3.3.x | Yes | Active (Current: v3.3.2) |
| < 3.3 | No | Unsupported |

## Security Model
- **Windows Server**: Firewall rules for USB/IP (`TCP 3240`) and discovery/control (`UDP/TCP 3241`) are restricted to Private/Domain profiles, with optional IP whitelist enforcement and `SecurityHelper.IsValidBusId()` input validation.
- **macOS Server**: Uses Apple Userspace `IOKit.framework` without third-party `.kext` kernel extensions.
- **Fail-Closed Updater**: Verifies installer `SHA256SUMS.txt` over HTTPS before execution.

## Reporting a Vulnerability
Please report security vulnerabilities privately via [GitHub Security Advisories](https://github.com/oscarlosu-lab/USBAnywhere-Server/security/advisories/new) instead of opening a public issue.
