// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Protocol & URB Descriptors Unit Tests
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import XCTest
@testable import USBAnywhereServerMac

final class ProtocolTests: XCTestCase {
    
    func testByteBufferIntegerRoundtrip() {
        let buf = ByteBuffer()
        buf.writeUInt8(0x42)
        buf.writeUInt16(0x1234)
        buf.writeUInt32(0x89ABCDEF)
        buf.writeInt32(-42)
        
        XCTAssertEqual(buf.readUInt8(), 0x42)
        XCTAssertEqual(buf.readUInt16(), 0x1234)
        XCTAssertEqual(buf.readUInt32(), 0x89ABCDEF)
        XCTAssertEqual(buf.readInt32(), -42)
    }
    
    func testByteBufferFixedString() {
        let buf = ByteBuffer()
        buf.writeFixedString("1-1", length: 32)
        
        let result = buf.readFixedString(length: 32)
        XCTAssertEqual(result, "1-1")
    }
    
    func testDevlistReplyEncoding() {
        let dev = USBDeviceInfo(
            busId: "1-1",
            path: "/sys/devices/pci/usb1/1-1",
            busNum: 1,
            devNum: 1,
            speed: USBIPConstants.speedHigh,
            idVendor: 0x046D,
            idProduct: 0xC216,
            bcdDevice: 0x0100,
            bDeviceClass: 0,
            bDeviceSubClass: 0,
            bDeviceProtocol: 0,
            bConfigurationValue: 1,
            bNumConfigurations: 1,
            bNumInterfaces: 1,
            productName: "Logitech Dual Action",
            interfaces: [USBInterfaceInfo(interfaceClass: 3, interfaceSubClass: 0, interfaceProtocol: 0)]
        )
        
        let data = USBIPPackets.encodeDevlistReply(devices: [dev])
        XCTAssertGreaterThan(data.count, 0)
        
        let buf = ByteBuffer(data: data)
        XCTAssertEqual(buf.readUInt16(), USBIPConstants.protocolVersion)
        XCTAssertEqual(buf.readUInt16(), USBIPConstants.opRepDevlist)
        XCTAssertEqual(buf.readUInt32(), USBIPConstants.statusOk)
        XCTAssertEqual(buf.readUInt32(), 1) // 1 device
    }
    
    func testImportReplyEncoding() {
        let dev = USBDeviceInfo(
            busId: "2-3",
            path: "/sys/devices/pci/usb2/2-3",
            busNum: 2,
            devNum: 3,
            speed: USBIPConstants.speedFull,
            idVendor: 0x045E,
            idProduct: 0x028E,
            bcdDevice: 0x0114,
            bDeviceClass: 0,
            bDeviceSubClass: 0,
            bDeviceProtocol: 0,
            bConfigurationValue: 1,
            bNumConfigurations: 1,
            bNumInterfaces: 1,
            productName: "Xbox 360 Controller"
        )
        
        let data = USBIPPackets.encodeImportReply(device: dev, status: USBIPConstants.statusOk)
        let buf = ByteBuffer(data: data)
        XCTAssertEqual(buf.readUInt16(), USBIPConstants.protocolVersion)
        XCTAssertEqual(buf.readUInt16(), USBIPConstants.opRepImport)
        XCTAssertEqual(buf.readUInt32(), USBIPConstants.statusOk)
    }
    
    func testRetSubmitEncoding() {
        let payload = Data([0x01, 0x02, 0x03, 0x04])
        let ret = USBIPPackets.encodeRetSubmit(
            seqnum: 100,
            devid: 1,
            direction: USBIPConstants.dirIn,
            ep: 1,
            status: 0,
            actualLength: 4,
            transferData: payload
        )
        
        XCTAssertEqual(ret.count, 48 + 4) // 48 bytes header + 4 bytes payload
        let buf = ByteBuffer(data: ret)
        XCTAssertEqual(buf.readUInt32(), USBIPConstants.retSubmit)
        XCTAssertEqual(buf.readUInt32(), 100) // seqnum
        XCTAssertEqual(buf.readUInt32(), 1)   // devid
        XCTAssertEqual(buf.readUInt32(), USBIPConstants.dirIn)
    }

    func testURBStandardDescriptors() {
        let dev = USBDeviceInfo(
            busId: "1-4",
            path: "/usb/1-4",
            busNum: 1,
            devNum: 4,
            speed: USBIPConstants.speedHigh,
            idVendor: 0x28DE,
            idProduct: 0x1304,
            bcdDevice: 0x0100,
            bDeviceClass: 0xEF,
            bDeviceSubClass: 0x02,
            bDeviceProtocol: 0x01,
            bConfigurationValue: 1,
            bNumConfigurations: 1,
            bNumInterfaces: 1,
            manufacturer: "Valve",
            productName: "Steam Controller",
            serialNumber: "SN1234",
            interfaces: [USBInterfaceInfo(interfaceClass: 0x03, interfaceSubClass: 0, interfaceProtocol: 0)]
        )
        let handler = URBHandler(device: dev)

        // 1. Device Descriptor (18 bytes, bcdUSB == 0x0200)
        let devDesc = handler.createDeviceDescriptor()
        XCTAssertEqual(devDesc.count, 18)
        XCTAssertEqual(devDesc[0], 18)
        XCTAssertEqual(devDesc[1], 1)
        XCTAssertEqual(devDesc[2], 0x00) // bcdUSB LSB
        XCTAssertEqual(devDesc[3], 0x02) // bcdUSB MSB (USB 2.00)

        // 2. Configuration Descriptor (Header 9 + Interface 9 + HID 9 + Endpoint 7 = 34 bytes)
        let cfgDesc = handler.createConfigurationDescriptor()
        XCTAssertEqual(cfgDesc.count, 34)
        XCTAssertEqual(cfgDesc[0], 9)
        XCTAssertEqual(cfgDesc[1], 2) // USB_DT_CONFIG
        let wTotalLen = UInt16(cfgDesc[2]) | (UInt16(cfgDesc[3]) << 8)
        XCTAssertEqual(Int(wTotalLen), cfgDesc.count)

        // 3. String Descriptors (Index 0 = LangID 0x0409, Index 2 = UTF-16LE Product)
        let langDesc = handler.createStringDescriptor(index: 0)
        XCTAssertEqual(langDesc, Data([4, 3, 0x09, 0x04]))
        let prodDesc = handler.createStringDescriptor(index: 2)
        XCTAssertGreaterThan(prodDesc.count, 4)
        XCTAssertEqual(prodDesc[1], 3) // USB_DT_STRING
    }

    func testMacUpdateCheckerSemVerAndShaSums() {
        XCTAssertTrue(MacUpdateChecker.isNewerVersion(latest: "v3.5.0", current: "3.4.0"))
        XCTAssertFalse(MacUpdateChecker.isNewerVersion(latest: "3.4.0", current: "3.4.0"))
        let sums = MacUpdateChecker.parseSha256Sums(
            "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  USBAnywhere-Server-macOS.dmg\n"
        )
        XCTAssertEqual(sums["USBAnywhere-Server-macOS.dmg"]?.count, 64)
    }

    func testVirtualMacMicDescriptorAndRingBuffer() {
        let mic = VirtualMacMicDevice()
        let dev = mic.buildDeviceDescriptor()
        XCTAssertEqual(dev.count, 18)
        let cfg = mic.buildUac1ConfigDescriptor()
        XCTAssertGreaterThanOrEqual(cfg.count, 36)
        mic.pushPcmFrame(Data([0x11, 0x22, 0x33, 0x44]))
        XCTAssertEqual(mic.readFrame(byteCount: 4), Data([0x11, 0x22, 0x33, 0x44]))
    }

    private final class MockTransport: USBDeviceTransport {
        func controlTransfer(bmRequestType: UInt8, bRequest: UInt8, wValue: UInt16, wIndex: UInt16, data: Data?, maxLength: Int) -> Data? {
            return Data([0xAA, 0xBB])
        }
        func bulkOrInterruptTransfer(endpoint: UInt8, direction: UInt32, data: Data?, maxLength: Int) -> Data? {
            return Data([0xCC, 0xDD, 0xEE])
        }
        func close() {}
    }

    func testURBHandlerDelegatesToTransport() {
        let dev = USBDeviceInfo(
            busId: "1-9", path: "/usb/1-9", busNum: 1, devNum: 9,
            speed: USBIPConstants.speedHigh, idVendor: 0x1209, idProduct: 0x5541,
            bcdDevice: 0x0100, bDeviceClass: 0, bDeviceSubClass: 0, bDeviceProtocol: 0,
            bConfigurationValue: 1, bNumConfigurations: 1, bNumInterfaces: 1
        )
        let handler = URBHandler(device: dev, transport: MockTransport())
        let cmd = USBIPPackets.CmdSubmit(
            seqnum: 7, devid: 1, direction: USBIPConstants.dirIn, ep: 1,
            transferFlags: 0, transferBufferLength: 3, startFrame: 0,
            numberOfPackets: 0, interval: 0, setup: Data(), transferBuffer: Data()
        )
        let reply = handler.handleSubmit(cmd: cmd)
        XCTAssertEqual(reply.suffix(3), Data([0xCC, 0xDD, 0xEE]))
    }
}
