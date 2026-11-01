// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - IOKit USB Device Enumeration & Shared State
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

#if os(macOS)
import IOKit
import IOKit.usb
#endif

public struct SharedServerState: Codable {
    public var boundBusIds: Set<String> = []
    public var dynamicBusIds: Set<String> = []
    public var claimedBusIds: Set<String> = []
    public var allowAll: Bool = true
    public var allowlist: [String] = []
    public var denylist: [String] = []
    public var protectLocalHid: Bool = false

    public init() {}
}

public final class IOKitDeviceManager {
    public static let shared = IOKitDeviceManager()
    public static var stateFilePath: String {
        let dir: String
        if geteuid() == 0 {
            dir = "/Library/Application Support/USBAnywhere"
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            dir = "\(home)/Library/Application Support/USBAnywhere"
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return "\(dir)/state.json"
    }
    
    private var state = SharedServerState()
    private var cachedDevices: [String: USBDeviceInfo] = [:]
    private let lock = NSLock()
    
    private init() {
        loadSharedState()
    }
    
    // MARK: - Cross-Process State Persistence
    
    public func loadSharedState() {
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
    }
    
    private func loadSharedStateUnlocked() {
        guard FileManager.default.fileExists(atPath: Self.stateFilePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: Self.stateFilePath)),
              let decoded = try? JSONDecoder().decode(SharedServerState.self, from: data) else {
            return
        }
        state = decoded
    }
    
    private func saveSharedStateUnlocked() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        let path = Self.stateFilePath
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    public func getState() -> SharedServerState {
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
        return state
    }

    public func updatePolicy(allowlist: [String]? = nil, denylist: [String]? = nil, protectLocalHid: Bool? = nil) {
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
        if let allow = allowlist { state.allowlist = allow }
        if let deny = denylist { state.denylist = deny }
        if let hid = protectLocalHid { state.protectLocalHid = hid }
        saveSharedStateUnlocked()
    }

    public func resetState() {
        lock.lock()
        defer { lock.unlock() }
        state = SharedServerState()
        saveSharedStateUnlocked()
    }

    // MARK: - Export Policy Verification

    public func isDeviceExportAllowed(busId: String, device: USBDeviceInfo? = nil) -> (allowed: Bool, reason: String) {
        lock.lock()
        loadSharedStateUnlocked()
        let currentState = state
        let dev = device ?? cachedDevices[busId]
        lock.unlock()

        if let dev = dev, dev.isHub {
            return (false, "USB Hubs cannot be shared")
        }

        let bId = busId.lowercased().trimmingCharacters(in: .whitespaces)
        let vp = dev?.vidPidString.lowercased() ?? ""
        let vid = vp.components(separatedBy: ":").first ?? ""

        let deny = currentState.denylist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        if deny.contains(bId) || (!vp.isEmpty && deny.contains(vp)) || (!vid.isEmpty && deny.contains(vid)) {
            return (false, "Device \(busId) (\(vp)) is blocked by host denylist")
        }

        if currentState.protectLocalHid, let dev = dev, dev.isHid {
            return (false, "Device \(busId) (\(vp)) is protected local HID")
        }

        let allow = currentState.allowlist.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        if !allow.isEmpty {
            let matched = allow.contains(bId) || (!vp.isEmpty && allow.contains(vp)) || (!vid.isEmpty && allow.contains(vid))
            if !matched {
                return (false, "Device \(busId) (\(vp)) is not in host allowlist")
            }
        }

        return (true, "OK")
    }

    // MARK: - Bind / Unbind Operations
    
    /// Binds a device busId for sharing over USB/IP
    public func bindDevice(busId: String, dynamic: Bool = false) -> Bool {
        let check = isDeviceExportAllowed(busId: busId)
        guard check.allowed else {
            return false
        }
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
        state.boundBusIds.insert(busId)
        if dynamic {
            state.dynamicBusIds.insert(busId)
        }
        saveSharedStateUnlocked()
        return true
    }
    
    /// Unbinds a device busId from sharing
    public func unbindDevice(busId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
        let removed = state.boundBusIds.remove(busId) != nil
        state.dynamicBusIds.remove(busId)
        state.claimedBusIds.remove(busId)
        saveSharedStateUnlocked()
        return removed
    }
    
    /// Checks if a busId is currently bound
    public func isBound(busId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
        return state.boundBusIds.contains(busId)
    }

    public func isDynamicBound(busId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
        return state.dynamicBusIds.contains(busId)
    }

    public func setClaimed(busId: String, claimed: Bool) {
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
        if claimed {
            state.claimedBusIds.insert(busId)
        } else {
            state.claimedBusIds.remove(busId)
        }
        saveSharedStateUnlocked()
    }

    public func isClaimed(busId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        loadSharedStateUnlocked()
        return state.claimedBusIds.contains(busId)
    }
    
    /// Binds all currently discovered non-hub devices that pass policy
    public func bindAllDevices() -> Int {
        let devices = enumerateDevices()
        var count = 0
        for dev in devices where !dev.isHub {
            if bindDevice(busId: dev.busId) {
                count += 1
            }
        }
        return count
    }
    
    /// Enumerates all currently connected physical USB devices on macOS (excluding USB Hubs)
    public func enumerateDevices() -> [USBDeviceInfo] {
        loadSharedState()
        #if os(macOS)
        var devices: [USBDeviceInfo] = []
        
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        var iterator: io_iterator_t = 0
        
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard kr == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }
        
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            
            if let devInfo = extractDeviceInfo(from: service) {
                // Skip USB Hubs and internal root controllers
                if devInfo.isHub || devInfo.idVendor == 0x1D6B {
                    continue
                }
                devInfo.isBound = isBound(busId: devInfo.busId)
                devInfo.isClaimed = isClaimed(busId: devInfo.busId)
                lock.lock()
                cachedDevices[devInfo.busId] = devInfo
                lock.unlock()
                devices.append(devInfo)
            }
        }
        return devices.sorted { $0.busId < $1.busId }
        #else
        return []
        #endif
    }
    
    #if os(macOS)
    private func extractDeviceInfo(from service: io_service_t) -> USBDeviceInfo? {
        guard let vendorIdNum = getProperty(service, key: kUSBVendorID) as? NSNumber,
              let productIdNum = getProperty(service, key: kUSBProductID) as? NSNumber else {
            return nil
        }
        
        let idVendor = vendorIdNum.uint16Value
        let idProduct = productIdNum.uint16Value
        
        let bcdDevice = (getProperty(service, key: "bcdDevice") as? NSNumber)?.uint16Value ?? 0x0100
        let bDeviceClass = (getProperty(service, key: "bDeviceClass") as? NSNumber)?.uint8Value ?? 0
        let bDeviceSubClass = (getProperty(service, key: "bDeviceSubClass") as? NSNumber)?.uint8Value ?? 0
        let bDeviceProtocol = (getProperty(service, key: "bDeviceProtocol") as? NSNumber)?.uint8Value ?? 0
        let bNumConfigurations = (getProperty(service, key: "bNumConfigurations") as? NSNumber)?.uint8Value ?? 1
        let bConfigurationValue = (getProperty(service, key: "bConfigurationValue") as? NSNumber)?.uint8Value ?? 1
        
        let locationId = (getProperty(service, key: "locationID") as? NSNumber)?.uint32Value ?? 0
        let busNum = max(1, (locationId >> 24) & 0xFF)
        let usbAddr = (getProperty(service, key: "USB Address") as? NSNumber)?.uint32Value
            ?? (getProperty(service, key: kUSBDevicePropertyAddress) as? NSNumber)?.uint32Value
        var portNibbles: [UInt32] = []
        for shift in stride(from: 20, through: 0, by: -4) {
            let nibble = (locationId >> shift) & 0x0F
            if nibble == 0 { break }
            portNibbles.append(nibble)
        }
        let devNum = usbAddr ?? max(1, (locationId >> 16) & 0xFF)
        let portChain = portNibbles.isEmpty ? "\(devNum)" : portNibbles.map(String.init).joined(separator: ".")
        let busId = usbAddr != nil ? "\(busNum)-\(usbAddr!)" : "\(busNum)-\(portChain)"
        let path = "/sys/devices/pci0000:00/0000:00:14.0/usb\(busNum)/\(busId)"
        
        // Strings
        let productName = getProperty(service, key: "USB Product Name") as? String
        let manufacturer = getProperty(service, key: "USB Vendor Name") as? String
        let serialNumber = getProperty(service, key: "USB Serial Number") as? String
        
        // Speed detection
        let speedVal = (getProperty(service, key: "Device Speed") as? NSNumber)?.uint32Value ?? 2
        let usbipSpeed: UInt32
        switch speedVal {
        case 0:
            usbipSpeed = USBIPConstants.speedLow
        case 1:
            usbipSpeed = USBIPConstants.speedFull
        case 2:
            usbipSpeed = USBIPConstants.speedHigh
        case 3, 4:
            usbipSpeed = USBIPConstants.speedSuper
        default:
            usbipSpeed = USBIPConstants.speedHigh
        }
        
        // Interfaces
        let interfaces = extractInterfaces(parentService: service)
        
        return USBDeviceInfo(
            busId: busId,
            path: path,
            busNum: busNum,
            devNum: devNum,
            speed: usbipSpeed,
            idVendor: idVendor,
            idProduct: idProduct,
            bcdDevice: bcdDevice,
            bDeviceClass: bDeviceClass,
            bDeviceSubClass: bDeviceSubClass,
            bDeviceProtocol: bDeviceProtocol,
            bConfigurationValue: bConfigurationValue,
            bNumConfigurations: bNumConfigurations,
            bNumInterfaces: UInt8(interfaces.count),
            manufacturer: manufacturer,
            productName: productName,
            serialNumber: serialNumber,
            interfaces: interfaces
        )
    }
    
    private func extractInterfaces(parentService: io_service_t) -> [USBInterfaceInfo] {
        var interfaces: [USBInterfaceInfo] = []
        var iterator: io_iterator_t = 0
        
        let kr = IORegistryEntryGetChildIterator(parentService, kIOServicePlane, &iterator)
        if kr == KERN_SUCCESS {
            defer { IOObjectRelease(iterator) }
            while case let child = IOIteratorNext(iterator), child != 0 {
                defer { IOObjectRelease(child) }
                if IOObjectConformsTo(child, kIOUSBInterfaceClassName) != 0 {
                    let ifClass = (getProperty(child, key: "bInterfaceClass") as? NSNumber)?.uint8Value ?? 0
                    let ifSubClass = (getProperty(child, key: "bInterfaceSubClass") as? NSNumber)?.uint8Value ?? 0
                    let ifProto = (getProperty(child, key: "bInterfaceProtocol") as? NSNumber)?.uint8Value ?? 0
                    interfaces.append(USBInterfaceInfo(interfaceClass: ifClass, interfaceSubClass: ifSubClass, interfaceProtocol: ifProto))
                }
            }
        }
        
        // Fallback default interface if none reported by plane
        if interfaces.isEmpty {
            interfaces.append(USBInterfaceInfo(interfaceClass: 0, interfaceSubClass: 0, interfaceProtocol: 0))
        }
        return interfaces
    }
    
    private func getProperty(_ service: io_service_t, key: String) -> Any? {
        let cfKey = key as CFString
        guard let prop = IORegistryEntryCreateCFProperty(service, cfKey, kCFAllocatorDefault, 0) else {
            return nil
        }
        return prop.takeRetainedValue()
    }
    #endif
}
