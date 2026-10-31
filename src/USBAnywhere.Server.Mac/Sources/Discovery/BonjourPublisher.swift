// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Bonjour / mDNS Publisher (_usbanywhere._tcp)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

public final class BonjourPublisher: NSObject, NetServiceDelegate {
    public static let shared = BonjourPublisher()
    private var netService: NetService?

    private override init() {
        super.init()
    }

    public func start(port: Int = 3240) {
        let hostName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        let serviceName = "USBAnywhere (\(hostName))"
        netService = NetService(domain: "local.", type: "_usbanywhere._tcp.", name: serviceName, port: Int32(port))
        
        let txtDict: [String: Data] = [
            "proto": "usbip".data(using: .utf8)!,
            "version": "3.1.0".data(using: .utf8)!,
            "platform": "macOS".data(using: .utf8)!
        ]
        let txtData = NetService.data(fromTXTRecord: txtDict)
        netService?.setTXTRecord(txtData)
        netService?.delegate = self
        netService?.publish()
    }

    public func stop() {
        netService?.stop()
        netService = nil
    }

    public func netServiceDidPublish(_ sender: NetService) {
        // Successfully published Bonjour service
    }

    public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        // Failed to publish Bonjour service
    }
}
