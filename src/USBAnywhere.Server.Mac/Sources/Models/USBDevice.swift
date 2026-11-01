// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - USB Device Model
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
import Combine

public struct USBInterfaceInfo: Codable, Equatable {
    public let interfaceClass: UInt8
    public let interfaceSubClass: UInt8
    public let interfaceProtocol: UInt8
    
    public init(interfaceClass: UInt8, interfaceSubClass: UInt8, interfaceProtocol: UInt8) {
        self.interfaceClass = interfaceClass
        self.interfaceSubClass = interfaceSubClass
        self.interfaceProtocol = interfaceProtocol
    }
}

/// Represents a physical USB device discovered via macOS IOKit
public final class USBDeviceInfo: Codable, CustomStringConvertible, Identifiable, ObservableObject {
    public var id: String { busId }
    public let busId: String
    public let path: String
    public let busNum: UInt32
    public let devNum: UInt32
    public let speed: UInt32
    
    public let idVendor: UInt16
    public let idProduct: UInt16
    public let bcdDevice: UInt16
    
    public let bDeviceClass: UInt8
    public let bDeviceSubClass: UInt8
    public let bDeviceProtocol: UInt8
    public let bConfigurationValue: UInt8
    public let bNumConfigurations: UInt8
    public let bNumInterfaces: UInt8
    
    public let manufacturer: String?
    public let productName: String?
    public let serialNumber: String?
    
    public var interfaces: [USBInterfaceInfo]
    public var isBound: Bool
    public var isClaimed: Bool
    
    public init(
        busId: String,
        path: String,
        busNum: UInt32,
        devNum: UInt32,
        speed: UInt32,
        idVendor: UInt16,
        idProduct: UInt16,
        bcdDevice: UInt16,
        bDeviceClass: UInt8,
        bDeviceSubClass: UInt8,
        bDeviceProtocol: UInt8,
        bConfigurationValue: UInt8,
        bNumConfigurations: UInt8,
        bNumInterfaces: UInt8,
        manufacturer: String? = nil,
        productName: String? = nil,
        serialNumber: String? = nil,
        interfaces: [USBInterfaceInfo] = [],
        isBound: Bool = false,
        isClaimed: Bool = false
    ) {
        self.busId = busId
        self.path = path
        self.busNum = busNum
        self.devNum = devNum
        self.speed = speed
        self.idVendor = idVendor
        self.idProduct = idProduct
        self.bcdDevice = bcdDevice
        self.bDeviceClass = bDeviceClass
        self.bDeviceSubClass = bDeviceSubClass
        self.bDeviceProtocol = bDeviceProtocol
        self.bConfigurationValue = bConfigurationValue
        self.bNumConfigurations = bNumConfigurations
        self.bNumInterfaces = bNumInterfaces
        self.manufacturer = manufacturer
        self.productName = productName
        self.serialNumber = serialNumber
        self.interfaces = interfaces
        self.isBound = isBound
        self.isClaimed = isClaimed
    }
    
    public var isSteamController: Bool {
        return idVendor == 0x28DE && [0x1304, 0x1102, 0x1142, 0x11FF, 0x1205].contains(idProduct)
    }

    public var cleanProductName: String {
        if let prod = productName, !prod.trimmingCharacters(in: .whitespaces).isEmpty {
            return prod
        }
        if isSteamController {
            return idProduct == 0x1304 ? "Steam Controller Wireless Receiver" : "Steam Controller"
        }
        return "USB Device"
    }

    public var displayName: String {
        let name = cleanProductName
        let mfg = manufacturer.map { "\($0) - " } ?? (isSteamController ? "Valve Software - " : "")
        let hexId = String(format: "%04X:%04X", idVendor, idProduct)
        return "\(mfg)\(name) (\(hexId))"
    }

    /// Formatted specifically for Windows Client TryQueryDynamicInventoryAsync regex:
    /// @"^\s*([0-9a-zA-Z\-\.]+)\s*:\s*(.+?)\s*(?:\(([0-9a-fA-F]{4}:[0-9a-fA-F]{4})\))?$"
    public var dynamicInventoryLine: String {
        let mfg = manufacturer.map { "\($0) " } ?? (isSteamController ? "Valve Software " : "")
        let baseDesc = "\(mfg)\(cleanProductName)".trimmingCharacters(in: .whitespaces)
        let tag = categoryTag
        let hexLower = String(format: "%04x:%04x", idVendor, idProduct)
        return "  \(busId)    : \(baseDesc)\(tag) (\(hexLower))"
    }

    public var vidPidString: String {
        return String(format: "%04X:%04X", idVendor, idProduct)
    }

    public var isHub: Bool {
        if bDeviceClass == 0x09 { return true }
        if interfaces.contains(where: { $0.interfaceClass == 0x09 }) { return true }
        let lowerName = (productName ?? "").lowercased()
        if lowerName.contains("root hub") || lowerName.contains("host controller") { return true }
        return false
    }

    public var isHid: Bool {
        if isSteamController || bDeviceClass == 0x03 { return true }
        return interfaces.contains(where: { $0.interfaceClass == 0x03 })
    }

    public var category: String {
        if isSteamController { return "HID / Gaming" }
        switch bDeviceClass {
        case 0x01: return "Audio"
        case 0x02: return "Communications"
        case 0x03: return "HID / Gaming"
        case 0x06: return "Imaging"
        case 0x07: return "Printer"
        case 0x08: return "Storage"
        case 0x09: return "Hub"
        case 0x0E: return "Video"
        case 0xE0: return "Wireless"
        default:
            for iface in interfaces {
                switch iface.interfaceClass {
                case 0x01: return "Audio"
                case 0x02: return "Communications"
                case 0x03: return "HID / Gaming"
                case 0x06: return "Imaging"
                case 0x07: return "Printer"
                case 0x08: return "Storage"
                case 0x09: return "Hub"
                case 0x0E: return "Video"
                case 0xE0: return "Wireless"
                default: break
                }
            }
            return "General USB"
        }
    }

    public var categoryTag: String {
        switch category {
        case "HID / Gaming":
            return isSteamController ? " [HID/Gamepad]" : " [HID]"
        case "Storage": return " [Storage]"
        case "Video": return " [Video]"
        case "Audio": return " [Audio]"
        default: return ""
        }
    }
    
    public var categoryEmoji: String {
        switch category {
        case "HID / Gaming": return "🎮"
        case "Video": return "📷"
        case "Audio": return "🎧"
        case "Storage": return "💾"
        case "Communications": return "🔌"
        case "Printer": return "🖨️"
        default: return "⚡"
        }
    }

    public var speedLabel: String {
        switch speed {
        case 1: return "Low Speed (1.5 Mb/s)"
        case 2: return "Full Speed (12 Mb/s)"
        case 3: return "High Speed (480 Mb/s)"
        case 4: return "SuperSpeed (5 Gb/s)"
        case 5: return "SuperSpeed+ (10 Gb/s)"
        default: return "USB (Standard)"
        }
    }
    
    public var description: String {
        let status = isBound ? (isClaimed ? "🟢 ATTACHED" : "🟡 SHARED") : "⚪ LOCAL"
        return "[\(busId)] \(displayName) - \(status)"
    }
}
