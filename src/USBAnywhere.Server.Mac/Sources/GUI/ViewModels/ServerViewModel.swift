// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - GUI Server View Model
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
import Combine
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(AppKit)
import AppKit
#endif

public final class ServerViewModel: ObservableObject {
    @Published public var isServerActive: Bool = false
    @Published public var devices: [USBDeviceInfo] = []
    @Published public var activeClientsCount: Int = 0
    @Published public var primaryIpAddress: String = "127.0.0.1"
    @Published public var logs: [String] = []
    @Published public var searchText: String = ""
    @Published public var autoBindCount: Int = 0
    @Published public var serverPort: UInt16 = 3240

    private var server: USBIPServer?
    private var timer: Timer?

    public init() {
        detectPrimaryIP()
        refreshDevices()
        startDiscoveryServices()
        startBackgroundMonitoring()
    }

    public func startServer(port: UInt16 = 3240) {
        guard !isServerActive else { return }
        self.serverPort = port
        server = USBIPServer(port: port)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try self?.server?.start()
            } catch {
                DispatchQueue.main.async {
                    self?.appendLog("❌ Server error: \(error.localizedDescription)")
                    self?.isServerActive = false
                }
            }
        }
        isServerActive = true
        appendLog("✅ USBAnywhere Server active on TCP port \(port)")
    }

    public func stopServer() {
        server?.stop()
        server = nil
        isServerActive = false
        appendLog("🛑 USBAnywhere Server stopped")
    }

    public func toggleServer() {
        if isServerActive {
            stopServer()
        } else {
            startServer(port: serverPort)
        }
    }

    public func refreshDevices() {
        let rawDevices = IOKitDeviceManager.shared.enumerateDevices()
        let autoBound = AutoBindManager.shared.getAutoBoundList()
        
        // Auto-export remembered devices
        for dev in rawDevices {
            if autoBound.contains(dev.vidPidString.uppercased()) && !dev.isBound {
                _ = IOKitDeviceManager.shared.bindDevice(busId: dev.busId)
                dev.isBound = true
            }
        }
        
        DispatchQueue.main.async {
            self.devices = rawDevices
            self.autoBindCount = autoBound.count
        }
    }

    public func toggleShare(device: USBDeviceInfo) {
        if device.isBound {
            _ = IOKitDeviceManager.shared.unbindDevice(busId: device.busId)
            device.isBound = false
            appendLog("⚪ Device unshared: \(device.displayName)")
        } else {
            _ = IOKitDeviceManager.shared.bindDevice(busId: device.busId)
            device.isBound = true
            appendLog("🟢 Device shared: \(device.displayName) on Bus \(device.busId)")
        }
        refreshDevices()
    }

    public func shareAll() {
        let count = IOKitDeviceManager.shared.bindAllDevices()
        appendLog("⚡ Shared all non-hub USB peripherals (\(count) exported)")
        refreshDevices()
    }

    public func stopAll() {
        for dev in devices where dev.isBound {
            _ = IOKitDeviceManager.shared.unbindDevice(busId: dev.busId)
        }
        appendLog("🛑 Stopped sharing all devices")
        refreshDevices()
    }

    public func toggleAutoBind(device: USBDeviceInfo) {
        let isNowAutoBound = AutoBindManager.shared.toggleAutoBind(vidPid: device.vidPidString)
        if isNowAutoBound && !device.isBound {
            _ = IOKitDeviceManager.shared.bindDevice(busId: device.busId)
            device.isBound = true
        }
        appendLog("📌 Auto-Bind \(isNowAutoBound ? "enabled" : "disabled") for [\(device.vidPidString)] \(device.productName ?? "")")
        refreshDevices()
    }

    public func copyIpToClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(primaryIpAddress, forType: .string)
        appendLog("📋 Server IP '\(primaryIpAddress)' copied to clipboard")
        #endif
    }

    public func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        DispatchQueue.main.async {
            self.logs.insert("[\(timestamp)] \(message)", at: 0)
            if self.logs.count > 100 {
                self.logs.removeLast()
            }
        }
    }

    private func detectPrimaryIP() {
        var address = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name.starts(with: "en") || name == "wlan0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    let ipStr = String(cString: hostname)
                    if !ipStr.starts(with: "127.") {
                        address = ipStr
                        break
                    }
                }
            }
            ptr = interface.ifa_next
        }
        self.primaryIpAddress = address
    }

    private func startDiscoveryServices() {
        DiscoveryResponder.shared.start()
        BonjourPublisher.shared.start(port: Int(serverPort))
    }

    private func startBackgroundMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshDevices()
        }
    }

    deinit {
        timer?.invalidate()
        DiscoveryResponder.shared.stop()
        BonjourPublisher.shared.stop()
        stopServer()
    }
}
