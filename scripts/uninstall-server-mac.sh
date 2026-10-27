#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# USBAnywhere Server for macOS — Clean Uninstaller
# Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
# Licensed under GPL v3
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${YELLOW}⚠️ Root privileges required. Re-running with sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

PLIST_PATH="/Library/LaunchDaemons/com.usbanywhere.server.plist"
BINARY_TARGET="/usr/local/bin/usbanywhere-server-mac"
LOG_FILE="/var/log/usbanywhere-server.log"

echo -e "${CYAN}Stopping and removing USBAnywhere Server for macOS...${NC}"

if [[ -f "${PLIST_PATH}" ]]; then
    launchctl unload -w "${PLIST_PATH}" 2>/dev/null || true
    rm -f "${PLIST_PATH}"
    echo -e "${GREEN}✓ LaunchDaemon removed.${NC}"
fi

if [[ -f "${BINARY_TARGET}" ]]; then
    rm -f "${BINARY_TARGET}"
    echo -e "${GREEN}✓ Binary removed from ${BINARY_TARGET}.${NC}"
fi

if [[ -f "/usr/local/bin/usbanywhere-ctl" ]]; then
    rm -f "/usr/local/bin/usbanywhere-ctl"
    echo -e "${GREEN}✓ Control Suite removed.${NC}"
fi

if [[ -f "${LOG_FILE}" ]]; then
    rm -f "${LOG_FILE}"
    echo -e "${GREEN}✓ Log file removed.${NC}"
fi

echo -e "${GREEN}${BOLD}USBAnywhere Server uninstalled cleanly.${NC}"
