// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Main CLI Entry Point & GUI Launcher
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

let version = "3.3.1"

func printBanner() {
    print("""
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║       🌐 USBAnywhere Server for macOS v\(version)                      ║
    ║   Share local USB peripherals over network (Moonlight/Sunshine/Sim)       ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    """)
}

func printHelp() {
    printBanner()
    print("""
    USAGE:
      usbanywhere-server-mac [command] [options]

    COMMANDS:
      gui, (no args)             Launch native macOS SwiftUI Dashboard & Menu Bar Extra
      list                       List connected USB devices and their bus IDs
      status [--json]            Display server and device status (supports JSON output)
      bind <busid>               Bind and export a USB device (e.g. 1-1)
      unbind <busid>             Unbind a shared USB device
      policy [action] [target]   View or configure host export policy (allow/deny/protect-hid)
      serve [options]            Start USB/IP server & Dynamic Control daemon in terminal
      control, dashboard         Open interactive Control Suite dashboard
      install-service            Install and start background launchd service (sudo)
      uninstall-service          Stop and remove background launchd service (sudo)
      help, --help, -h           Show this help information
      version, --version, -v     Display version information

    OPTIONS (for 'serve'):
      --port <port>              TCP port to listen on (default: 3240)
      --auto-bind                Automatically export all local USB devices (except Hubs)

    EXAMPLES:
      usbanywhere-server-mac                     # Launch GUI Desktop App
      usbanywhere-server-mac list                # List USB peripherals
      usbanywhere-server-mac status --json       # Query server status as JSON
      usbanywhere-server-mac bind 1-1            # Bind peripheral on bus 1-1
      usbanywhere-server-mac serve               # On-Demand Dynamic Server daemon
      sudo usbanywhere-server-mac install-service
    """)
}

let args = Array(CommandLine.arguments.dropFirst())

// If launched with no arguments or with gui/--gui, launch native macOS SwiftUI application
if args.isEmpty || args.contains("--gui") || args.first == "gui" {
    #if canImport(SwiftUI)
    if #available(macOS 13.0, *) {
        USBAnywhereServerApp.main()
        exit(0)
    } else {
        print("Notice: Native SwiftUI GUI requires macOS 13.0 or later.")
        printHelp()
        exit(0)
    }
    #else
    printHelp()
    exit(0)
    #endif
}

let command = args[0].lowercased()

switch command {
case "help", "--help", "-h":
    printHelp()
    
case "version", "--version", "-v":
    print("USBAnywhere Server for macOS v\(version)")

case "control", "dashboard":
    let ctlPath = "/usr/local/bin/usbanywhere-ctl"
    if FileManager.default.fileExists(atPath: ctlPath) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["python3", ctlPath] + Array(CommandLine.arguments.dropFirst(2))
        try? task.run()
        task.waitUntilExit()
        exit(task.terminationStatus)
    } else {
        printBanner()
        print("💡 USBAnywhere Control Suite: run 'usbanywhere-ctl' or re-run installer.")
    }
    
case "list":
    if args.contains("--dynamic") || args.contains("--raw") {
        let devices = IOKitDeviceManager.shared.enumerateDevices()
        for dev in devices {
            print(dev.dynamicInventoryLine)
        }
    } else {
        printBanner()
        let devices = IOKitDeviceManager.shared.enumerateDevices()
        if devices.isEmpty {
            print("No USB devices found or permission denied.")
        } else {
            print("Discovered USB Devices:")
            for dev in devices {
                print("  \(dev)")
            }
        }
    }

case "status":
    let jsonReply = ControlServer.processCommand("STATUS")
    if args.contains("--json") {
        print(jsonReply)
    } else {
        printBanner()
        let devices = IOKitDeviceManager.shared.enumerateDevices()
        let boundCount = devices.filter { $0.isBound }.count
        let claimedCount = devices.filter { $0.isClaimed }.count
        print("Status:            ACTIVE (v\(version))")
        print("USB/IP Port:       3240 (TCP)")
        print("Dynamic API Port:  3241 (TCP/UDP)")
        print("Detected Devices:  \(devices.count) (\(boundCount) shared, \(claimedCount) attached)")
    }
    
case "bind":
    guard args.count >= 2 else {
        print("❌ Error: Missing bus ID. Usage: usbanywhere-server-mac bind <busid>")
        exit(1)
    }
    let busId = args[1]
    let check = IOKitDeviceManager.shared.isDeviceExportAllowed(busId: busId)
    guard check.allowed else {
        print("🛡️ [Policy Block] Cannot share '\(busId)': \(check.reason)")
        exit(1)
    }
    _ = IOKitDeviceManager.shared.bindDevice(busId: busId)
    print("✅ Device '\(busId)' is now marked for export.")
    
case "unbind":
    guard args.count >= 2 else {
        print("❌ Error: Missing bus ID. Usage: usbanywhere-server-mac unbind <busid>")
        exit(1)
    }
    let busId = args[1]
    if IOKitDeviceManager.shared.unbindDevice(busId: busId) {
        print("✅ Device '\(busId)' unbound successfully.")
    } else {
        print("⚠️ Device '\(busId)' was not bound.")
    }

case "policy":
    let st = IOKitDeviceManager.shared.getState()
    let action = args.count >= 2 ? args[1].lowercased() : "show"
    let target = args.count >= 3 ? args[2] : ""
    switch action {
    case "show":
        print("═══ 🛡️ USBAnywhere macOS Host Export Policy ═══")
        print("Protect local HID: \(st.protectLocalHid ? "ACTIVE" : "OFF")")
        print("Allowlist (\(st.allowlist.count)): \(st.allowlist)")
        print("Denylist (\(st.denylist.count)):  \(st.denylist)")
    case "deny" where !target.isEmpty:
        var list = st.denylist
        if !list.contains(target) { list.append(target) }
        IOKitDeviceManager.shared.updatePolicy(denylist: list)
        print("✓ Added '\(target)' to denylist.")
    case "allow" where !target.isEmpty:
        var list = st.allowlist
        if !list.contains(target) { list.append(target) }
        IOKitDeviceManager.shared.updatePolicy(allowlist: list)
        print("✓ Added '\(target)' to allowlist.")
    case "remove" where !target.isEmpty:
        let deny = st.denylist.filter { $0.caseInsensitiveCompare(target) != .orderedSame }
        let allow = st.allowlist.filter { $0.caseInsensitiveCompare(target) != .orderedSame }
        IOKitDeviceManager.shared.updatePolicy(allowlist: allow, denylist: deny)
        print("✓ Removed '\(target)' from policy lists.")
    case "protect-hid":
        let enabled = ["on", "true", "1", "yes"].contains(target.lowercased())
        IOKitDeviceManager.shared.updatePolicy(protectLocalHid: enabled)
        print("✓ Local HID Protection is now \(enabled ? "ENABLED" : "DISABLED").")
    default:
        print("Usage: usbanywhere-server-mac policy [show | deny <id> | allow <id> | remove <id> | protect-hid <on|off>]")
    }
    
case "install-service":
    if LaunchdService.install() {
        exit(0)
    } else {
        exit(1)
    }
    
case "uninstall-service":
    if LaunchdService.uninstall() {
        exit(0)
    } else {
        exit(1)
    }
    
case "serve":
    printBanner()
    var port: UInt16 = USBIPConstants.defaultPort
    var autoBind = false
    
    var idx = 1
    while idx < args.count {
        let opt = args[idx]
        if opt == "--port", idx + 1 < args.count, let p = UInt16(args[idx + 1]) {
            port = p
            idx += 1
        } else if opt == "--auto-bind" {
            autoBind = true
        }
        idx += 1
    }
    
    // Auto-export remembered pinned devices (and all non-hub devices if --auto-bind is passed)
    let rawDevices = IOKitDeviceManager.shared.enumerateDevices()
    let pinned = AutoBindManager.shared.getAutoBoundList()
    for dev in rawDevices where pinned.contains(dev.vidPidString.uppercased()) {
        _ = IOKitDeviceManager.shared.bindDevice(busId: dev.busId)
    }

    if autoBind {
        let count = IOKitDeviceManager.shared.bindAllDevices()
        print("⚡ Auto-bind enabled: \(count) local device(s) exported.")
    } else {
        print("🔄 Dynamic On-Demand Mode (Zero-Host-Lockout): Devices remain local until requested by a client.")
    }
    
    let server = USBIPServer(port: port)
    
    // Trap SIGINT and SIGTERM for graceful exit
    signal(SIGINT) { _ in
        print("\n🛑 Stopping server...")
        exit(0)
    }
    signal(SIGTERM) { _ in
        print("\n🛑 Terminating server...")
        exit(0)
    }
    
    do {
        try server.start()
    } catch {
        print("❌ Fatal error starting server: \(error.localizedDescription)")
        exit(1)
    }

default:
    print("Unknown command: '\(command)'")
    printHelp()
    exit(1)
}
