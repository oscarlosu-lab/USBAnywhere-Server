// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - URB Request / Response Handler
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
        
        // Interrupt / Bulk In Transfers (Joysticks, Keyboards, Mice, Storage)
        if direction == USBIPConstants.dirIn {
            // Emulate or pipe incoming data
            let mockData = Data(repeating: 0, count: min(Int(bufferLength), 64))
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
        
        // Standard GET_DESCRIPTOR (0x80, 0x06)
        if bmRequestType == 0x80 && bRequest == 0x06 {
            let descType = UInt8(wValue >> 8)
            
            if descType == 1 { // Device Descriptor
                let devDesc = createDeviceDescriptor()
                let sendLen = min(Int(wLength), devDesc.count)
                return USBIPPackets.encodeRetSubmit(
                    seqnum: cmd.seqnum,
                    devid: cmd.devid,
                    direction: USBIPConstants.dirIn,
                    ep: 0,
                    status: 0,
                    actualLength: UInt32(sendLen),
                    transferData: devDesc.prefix(sendLen)
                )
            }
        }
        
        // Default success for control requests (e.g. SET_CONFIGURATION, SET_INTERFACE)
        return USBIPPackets.encodeRetSubmit(
            seqnum: cmd.seqnum,
            devid: cmd.devid,
            direction: cmd.direction,
            ep: 0,
            status: 0,
            actualLength: 0
        )
    }
    
    private func createDeviceDescriptor() -> Data {
        var d = Data()
        d.append(18) // bLength
        d.append(1)  // bDescriptorType (Device)
        d.append(contentsOf: [UInt8(device.bcdDevice & 0xFF), UInt8(device.bcdDevice >> 8)]) // bcdUSB
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
        d.append(device.bNumConfigurations)
        return d
    }
}
