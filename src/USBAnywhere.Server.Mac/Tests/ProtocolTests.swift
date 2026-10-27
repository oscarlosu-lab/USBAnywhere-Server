// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Protocol Unit Tests
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
}
