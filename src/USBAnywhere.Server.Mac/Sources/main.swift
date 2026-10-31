// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Main CLI Entry Point & GUI Launcher
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

let version = "3.1.0"

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
      bind <busid>               Bind and export a USB device (e.g. 1-1)
      unbind <busid>             Unbind a shared USB device
      serve [options]            Start USB/IP server daemon in terminal
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
      usbanywhere-server-mac bind 1-1            # Bind peripheral on bus 1-1
      usbanywhere-server-mac serve --auto-bind   # Headless CLI server daemon
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
    
case "bind":
    guard args.count >= 2 else {
        print("❌ Error: Missing bus ID. Usage: usbanywhere-server-mac bind <busid>")
        exit(1)
    }
    let busId = args[1]
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
    
    if autoBind {
        let count = IOKitDeviceManager.shared.bindAllDevices()
        print("⚡ Auto-bind enabled: \(count) local device(s) exported.")
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
