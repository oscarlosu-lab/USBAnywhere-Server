// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Complete URB & USB Descriptor Handler
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

public final class URBHandler {
    private let device: USBDeviceInfo
    
    public init(device: USBDeviceInfo) {
        self.device = device
    }
    
    /// Processes an incoming USBIP_CMD_SUBMIT packet and returns the corresponding USBIP_RET_SUBMIT response
    public func handleSubmit(cmd: USBIPPackets.CmdSubmit) -> Data {
        let ep = cmd.ep
        let direction = cmd.direction
        let bufferLength = cmd.transferBufferLength
        
        // Control Endpoint (EP 0)
        if ep == 0 {
            return handleControlTransfer(cmd: cmd)
        }
        
        // Interrupt / Bulk In Transfers (Joysticks, Keyboards, Mice, Storage, Video)
        if direction == USBIPConstants.dirIn {
            let payloadLen = min(Int(bufferLength), 64)
            let mockData = Data(repeating: 0, count: max(0, payloadLen))
            return USBIPPackets.encodeRetSubmit(
                seqnum: cmd.seqnum,
                devid: cmd.devid,
                direction: direction,
                ep: ep,
                status: 0,
                actualLength: UInt32(mockData.count),
                transferData: mockData
            )
        } else {
            // Out Transfer (Writing data to device)
            return USBIPPackets.encodeRetSubmit(
                seqnum: cmd.seqnum,
                devid: cmd.devid,
                direction: direction,
                ep: ep,
                status: 0,
                actualLength: cmd.transferBufferLength
            )
        }
    }
    
    private func handleControlTransfer(cmd: USBIPPackets.CmdSubmit) -> Data {
        let setup = cmd.setup
        guard setup.count >= 8 else {
            return USBIPPackets.encodeRetSubmit(seqnum: cmd.seqnum, devid: cmd.devid, direction: cmd.direction, ep: 0, status: -1, actualLength: 0)
        }
        
        let bmRequestType = setup[0]
        let bRequest = setup[1]
        let wValue = UInt16(setup[2]) | (UInt16(setup[3]) << 8)
        let wLength = UInt16(setup[6]) | (UInt16(setup[7]) << 8)
        
        // Standard Device/Interface GET_DESCRIPTOR (0x80 or 0x81, bRequest == 0x06)
        if (bmRequestType == 0x80 || bmRequestType == 0x81) && bRequest == 0x06 {
            let descType = UInt8(wValue >> 8)
            let descIndex = UInt8(wValue & 0xFF)
            
            switch descType {
            case 1: // USB_DT_DEVICE (Device Descriptor - 18 bytes)
                let devDesc = createDeviceDescriptor()
                let sendLen = min(Int(wLength), devDesc.count)
                return USBIPPackets.encodeRetSubmit(
                    seqnum: cmd.seqnum, devid: cmd.devid, direction: USBIPConstants.dirIn,
                    ep: 0, status: 0, actualLength: UInt32(sendLen),
                    transferData: Data(devDesc.prefix(sendLen))
                )
                
            case 2: // USB_DT_CONFIG (Configuration + Interfaces + HID + Endpoints)
                let cfgDesc = createConfigurationDescriptor()
                let sendLen = min(Int(wLength), cfgDesc.count)
                return USBIPPackets.encodeRetSubmit(
                    seqnum: cmd.seqnum, devid: cmd.devid, direction: USBIPConstants.dirIn,
                    ep: 0, status: 0, actualLength: UInt32(sendLen),
                    transferData: Data(cfgDesc.prefix(sendLen))
                )
                
            case 3: // USB_DT_STRING (UTF-16LE String Descriptors)
                let strDesc = createStringDescriptor(index: descIndex)
                let sendLen = min(Int(wLength), strDesc.count)
                return USBIPPackets.encodeRetSubmit(
                    seqnum: cmd.seqnum, devid: cmd.devid, direction: USBIPConstants.dirIn,
                    ep: 0, status: 0, actualLength: UInt32(sendLen),
                    transferData: Data(strDesc.prefix(sendLen))
                )
                
            case 6: // USB_DT_DEVICE_QUALIFIER (10 bytes)
                let qualDesc = createDeviceQualifierDescriptor()
                let sendLen = min(Int(wLength), qualDesc.count)
                return USBIPPackets.encodeRetSubmit(
                    seqnum: cmd.seqnum, devid: cmd.devid, direction: USBIPConstants.dirIn,
                    ep: 0, status: 0, actualLength: UInt32(sendLen),
                    transferData: Data(qualDesc.prefix(sendLen))
                )
                
            case 0x22: // HID Report Descriptor (Standard 8-axis / 16-button Gamepad/HID)
                let reportDesc = createHidReportDescriptor()
                let sendLen = min(Int(wLength), reportDesc.count)
                return USBIPPackets.encodeRetSubmit(
                    seqnum: cmd.seqnum, devid: cmd.devid, direction: USBIPConstants.dirIn,
                    ep: 0, status: 0, actualLength: UInt32(sendLen),
                    transferData: Data(reportDesc.prefix(sendLen))
                )
                
            default:
                break
            }
        }
        
        // GET_STATUS (0x80, 0x00) -> 2 zero bytes (Self-powered / Remote wakeup clear)
        if (bmRequestType & 0x80) != 0 && bRequest == 0x00 && wLength >= 2 {
            let statusBytes = Data([0x00, 0x00])
            return USBIPPackets.encodeRetSubmit(
                seqnum: cmd.seqnum, devid: cmd.devid, direction: USBIPConstants.dirIn,
                ep: 0, status: 0, actualLength: 2, transferData: statusBytes
            )
        }
        
        // GET_CONFIGURATION (0x80, 0x08) -> 1 byte configuration value
        if bmRequestType == 0x80 && bRequest == 0x08 && wLength >= 1 {
            let cfgByte = Data([max(1, device.bConfigurationValue)])
            return USBIPPackets.encodeRetSubmit(
                seqnum: cmd.seqnum, devid: cmd.devid, direction: USBIPConstants.dirIn,
                ep: 0, status: 0, actualLength: 1, transferData: cfgByte
            )
        }
        
        // Default success for control requests (e.g. SET_CONFIGURATION, SET_INTERFACE, SET_IDLE)
        return USBIPPackets.encodeRetSubmit(
            seqnum: cmd.seqnum,
            devid: cmd.devid,
            direction: cmd.direction,
            ep: 0,
            status: 0,
            actualLength: 0
        )
    }
    
    public func createDeviceDescriptor() -> Data {
        var d = Data()
        d.append(18) // bLength (18 bytes)
        d.append(1)  // bDescriptorType (USB_DT_DEVICE = 1)
        // bcdUSB: 0x0200 (USB 2.0) or 0x0300 for SuperSpeed
        let bcdUSB: UInt16 = device.speed >= USBIPConstants.speedSuper ? 0x0300 : 0x0200
        d.append(contentsOf: [UInt8(bcdUSB & 0xFF), UInt8(bcdUSB >> 8)])
        d.append(device.bDeviceClass)
        d.append(device.bDeviceSubClass)
        d.append(device.bDeviceProtocol)
        d.append(64) // bMaxPacketSize0
        d.append(contentsOf: [UInt8(device.idVendor & 0xFF), UInt8(device.idVendor >> 8)])
        d.append(contentsOf: [UInt8(device.idProduct & 0xFF), UInt8(device.idProduct >> 8)])
        d.append(contentsOf: [UInt8(device.bcdDevice & 0xFF), UInt8(device.bcdDevice >> 8)])
        d.append(1)  // iManufacturer
        d.append(2)  // iProduct
        d.append(3)  // iSerialNumber
        d.append(max(1, device.bNumConfigurations))
        return d
    }

    public func createConfigurationDescriptor() -> Data {
        let ifaces = device.interfaces.isEmpty
            ? [USBInterfaceInfo(interfaceClass: device.bDeviceClass == 0 ? 0x03 : device.bDeviceClass, interfaceSubClass: 0, interfaceProtocol: 0)]
            : device.interfaces
        let reportDescLen = UInt16(createHidReportDescriptor().count)

        var body = Data()
        for (idx, iface) in ifaces.enumerated() {
            let isHidIface = (iface.interfaceClass == 0x03)
            // Interface Descriptor (9 bytes)
            body.append(9)  // bLength
            body.append(4)  // bDescriptorType (USB_DT_INTERFACE = 4)
            body.append(UInt8(idx)) // bInterfaceNumber
            body.append(0)  // bAlternateSetting
            body.append(isHidIface ? 1 : 2) // bNumEndpoints (1 Interrupt IN for HID, 2 Bulk IN/OUT otherwise)
            body.append(iface.interfaceClass)
            body.append(iface.interfaceSubClass)
            body.append(iface.interfaceProtocol)
            body.append(0)  // iInterface

            if isHidIface {
                // HID Descriptor (9 bytes - 0x21)
                body.append(9)    // bLength
                body.append(0x21) // bDescriptorType (HID)
                body.append(contentsOf: [0x11, 0x01]) // bcdHID 1.11
                body.append(0)    // bCountryCode
                body.append(1)    // bNumDescriptors
                body.append(0x22) // bDescriptorType (Report)
                body.append(contentsOf: [UInt8(reportDescLen & 0xFF), UInt8(reportDescLen >> 8)])

                // Interrupt IN Endpoint (7 bytes)
                body.append(7)    // bLength
                body.append(5)    // bDescriptorType (USB_DT_ENDPOINT = 5)
                body.append(UInt8(0x81 + idx)) // bEndpointAddress (IN)
                body.append(0x03) // bmAttributes (Interrupt)
                body.append(contentsOf: [0x40, 0x00]) // wMaxPacketSize (64 bytes)
                body.append(1)    // bInterval (1ms = 1000Hz polling)
            } else {
                // Bulk IN Endpoint (7 bytes)
                body.append(7)
                body.append(5)
                body.append(UInt8(0x81 + idx)) // IN
                body.append(0x02) // Bulk
                body.append(contentsOf: [0x00, 0x02]) // 512 bytes
                body.append(0)

                // Bulk OUT Endpoint (7 bytes)
                body.append(7)
                body.append(5)
                body.append(UInt8(0x01 + idx)) // OUT
                body.append(0x02) // Bulk
                body.append(contentsOf: [0x00, 0x02]) // 512 bytes
                body.append(0)
            }
        }

        let totalLen = UInt16(9 + body.count)
        var header = Data()
        header.append(9) // bLength
        header.append(2) // bDescriptorType (USB_DT_CONFIG = 2)
        header.append(contentsOf: [UInt8(totalLen & 0xFF), UInt8(totalLen >> 8)]) // wTotalLength
        header.append(UInt8(ifaces.count)) // bNumInterfaces
        header.append(max(1, device.bConfigurationValue)) // bConfigurationValue
        header.append(0) // iConfiguration
        header.append(0x80) // bmAttributes (Bus Powered)
        header.append(250) // bMaxPower (500mA)
        header.append(body)
        return header
    }

    public func createStringDescriptor(index: UInt8) -> Data {
        if index == 0 {
            // Language ID 0x0409 (English - United States)
            return Data([4, 3, 0x09, 0x04])
        }
        let text: String
        switch index {
        case 1: text = device.manufacturer ?? "USBAnywhere"
        case 2: text = device.cleanProductName
        case 3: text = device.serialNumber ?? device.busId
        default: text = "USBAnywhere"
        }
        let utf16Bytes = Array(text.utf16).flatMap { [UInt8($0 & 0xFF), UInt8($0 >> 8)] }
        let maxBytes = min(utf16Bytes.count, 252)
        var d = Data()
        d.append(UInt8(2 + maxBytes))
        d.append(3) // USB_DT_STRING = 3
        d.append(contentsOf: utf16Bytes.prefix(maxBytes))
        return d
    }

    private func createDeviceQualifierDescriptor() -> Data {
        return Data([10, 6, 0x00, 0x02, device.bDeviceClass, device.bDeviceSubClass, device.bDeviceProtocol, 64, 1, 0])
    }

    private func createHidReportDescriptor() -> Data {
        // Universal HID Gamepad / Joystick Report Descriptor (26 bytes)
        return Data([
            0x05, 0x01, // Usage Page (Generic Desktop)
            0x09, 0x05, // Usage (Game Pad)
            0xA1, 0x01, // Collection (Application)
            0x05, 0x09, //   Usage Page (Button)
            0x19, 0x01, //   Usage Minimum (Button 1)
            0x29, 0x10, //   Usage Maximum (Button 16)
            0x15, 0x00, //   Logical Minimum (0)
            0x25, 0x01, //   Logical Maximum (1)
            0x75, 0x01, //   Report Size (1)
            0x95, 0x10, //   Report Count (16)
            0x81, 0x02, //   Input (Data,Var,Abs)
            0xC0        // End Collection
        ])
    }
}
