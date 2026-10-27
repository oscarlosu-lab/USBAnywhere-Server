// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - IOKit USB Device Enumeration & Manager
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

#if os(macOS)
import IOKit
import IOKit.usb
#endif

public final class IOKitDeviceManager {
    public static let shared = IOKitDeviceManager()
    
    private var boundBusIds: Set<String> = []
    private let lock = NSLock()
    
    private init() {}
    
    /// Binds a device busId for sharing over USB/IP
    public func bindDevice(busId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        boundBusIds.insert(busId)
        return true
    }
    
    /// Unbinds a device busId from sharing
    public func unbindDevice(busId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return boundBusIds.remove(busId) != nil
    }
    
    /// Checks if a busId is currently bound
    public func isBound(busId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return boundBusIds.contains(busId)
    }
    
    /// Binds all currently discovered non-hub devices
    public func bindAllDevices() -> Int {
        let devices = enumerateDevices()
        var count = 0
        for dev in devices where dev.bDeviceClass != 0x09 { // Skip USB Hubs
            _ = bindDevice(busId: dev.busId)
            count += 1
        }
        return count
    }
    
    /// Enumerates all currently connected USB devices on macOS
    public func enumerateDevices() -> [USBDeviceInfo] {
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
                devInfo.isBound = isBound(busId: devInfo.busId)
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
        let busNum = (locationId >> 24) & 0xFF
        let devNum = (locationId >> 16) & 0xFF
        let busId = "\(busNum)-\(devNum)"
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
        case 3:
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
