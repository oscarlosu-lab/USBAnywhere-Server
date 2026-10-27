// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - USB/IP Network Packet Serialization
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

public final class ByteBuffer {
    private var data: Data
    private var offset: Int = 0
    
    public init(data: Data = Data()) {
        self.data = data
    }
    
    public var rawData: Data { data }
    public var remainingBytes: Int { data.count - offset }
    
    // MARK: - Writers (Big Endian)
    public func writeUInt8(_ value: UInt8) {
        data.append(value)
    }
    
    public func writeUInt16(_ value: UInt16) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }
    
    public func writeUInt32(_ value: UInt32) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }
    
    public func writeInt32(_ value: Int32) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.append(contentsOf: $0) }
    }
    
    public func writeData(_ bytes: Data) {
        data.append(bytes)
    }
    
    public func writeFixedString(_ string: String, length: Int) {
        var utf8 = Array(string.utf8.prefix(length))
        while utf8.count < length {
            utf8.append(0)
        }
        data.append(contentsOf: utf8)
    }
    
    // MARK: - Readers (Big Endian)
    public func readUInt8() -> UInt8? {
        guard offset < data.count else { return nil }
        let val = data[offset]
        offset += 1
        return val
    }
    
    public func readUInt16() -> UInt16? {
        guard offset + 2 <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + 2))
        offset += 2
        return sub.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }
    
    public func readUInt32() -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + 4))
        offset += 4
        return sub.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }
    
    public func readInt32() -> Int32? {
        guard offset + 4 <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + 4))
        offset += 4
        return sub.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
    }
    
    public func readData(length: Int) -> Data? {
        guard offset + length <= data.count else { return nil }
        let sub = data.subdata(in: offset..<(offset + length))
        offset += length
        return sub
    }
    
    public func readFixedString(length: Int) -> String? {
        guard let chunk = readData(length: length) else { return nil }
        let nullTerm = chunk.split(separator: 0, maxSplits: 1, omittingEmptySubsequences: false).first ?? chunk
        return String(data: nullTerm, encoding: .utf8) ?? ""
    }
}

// MARK: - Packet Serializers
public enum USBIPPackets {
    
    /// Encodes OP_REP_DEVLIST response containing all exported devices
    public static func encodeDevlistReply(devices: [USBDeviceInfo]) -> Data {
        let buf = ByteBuffer()
        // Header
        buf.writeUInt16(USBIPConstants.protocolVersion)
        buf.writeUInt16(USBIPConstants.opRepDevlist)
        buf.writeUInt32(USBIPConstants.statusOk)
        
        // Exported count
        buf.writeUInt32(UInt32(devices.count))
        
        for dev in devices {
            encodeUSBDevice(dev, into: buf)
            for iface in dev.interfaces {
                buf.writeUInt8(iface.interfaceClass)
                buf.writeUInt8(iface.interfaceSubClass)
                buf.writeUInt8(iface.interfaceProtocol)
                buf.writeUInt8(0) // padding
            }
        }
        return buf.rawData
    }
    
    /// Encodes OP_REP_IMPORT response
    public static func encodeImportReply(device: USBDeviceInfo?, status: UInt32 = USBIPConstants.statusOk) -> Data {
        let buf = ByteBuffer()
        buf.writeUInt16(USBIPConstants.protocolVersion)
        buf.writeUInt16(USBIPConstants.opRepImport)
        buf.writeUInt32(status)
        
        if let dev = device, status == USBIPConstants.statusOk {
            encodeUSBDevice(dev, into: buf)
        }
        return buf.rawData
    }
    
    private static func encodeUSBDevice(_ dev: USBDeviceInfo, into buf: ByteBuffer) {
        buf.writeFixedString(dev.path, length: USBIPConstants.maxPathLength)
        buf.writeFixedString(dev.busId, length: USBIPConstants.maxBusIdLength)
        buf.writeUInt32(dev.busNum)
        buf.writeUInt32(dev.devNum)
        buf.writeUInt32(dev.speed)
        
        buf.writeUInt16(dev.idVendor)
        buf.writeUInt16(dev.idProduct)
        buf.writeUInt16(dev.bcdDevice)
        
        buf.writeUInt8(dev.bDeviceClass)
        buf.writeUInt8(dev.bDeviceSubClass)
        buf.writeUInt8(dev.bDeviceProtocol)
        buf.writeUInt8(dev.bConfigurationValue)
        buf.writeUInt8(dev.bNumConfigurations)
        buf.writeUInt8(UInt8(dev.interfaces.count))
    }
    
    // MARK: - URB Submit Packet
    public struct CmdSubmit {
        public let seqnum: UInt32
        public let devid: UInt32
        public let direction: UInt32
        public let ep: UInt32
        public let transferFlags: UInt32
        public let transferBufferLength: UInt32
        public let startFrame: UInt32
        public let numberOfPackets: UInt32
        public let interval: UInt32
        public let setup: Data // 8 bytes
        public let transferBuffer: Data
        
        public static func decode(from buf: ByteBuffer) -> CmdSubmit? {
            guard let seqnum = buf.readUInt32(),
                  let devid = buf.readUInt32(),
                  let direction = buf.readUInt32(),
                  let ep = buf.readUInt32(),
                  let transferFlags = buf.readUInt32(),
                  let transferBufferLength = buf.readUInt32(),
                  let startFrame = buf.readUInt32(),
                  let numberOfPackets = buf.readUInt32(),
                  let interval = buf.readUInt32(),
                  let setup = buf.readData(length: 8) else {
                return nil
            }
            
            var payload = Data()
            if direction == USBIPConstants.dirOut && transferBufferLength > 0 {
                guard let data = buf.readData(length: Int(transferBufferLength)) else {
                    return nil
                }
                payload = data
            }
            
            return CmdSubmit(
                seqnum: seqnum,
                devid: devid,
                direction: direction,
                ep: ep,
                transferFlags: transferFlags,
                transferBufferLength: transferBufferLength,
                startFrame: startFrame,
                numberOfPackets: numberOfPackets,
                interval: interval,
                setup: setup,
                transferBuffer: payload
            )
        }
    }
    
    // MARK: - URB Return Packet
    public static func encodeRetSubmit(
        seqnum: UInt32,
        devid: UInt32,
        direction: UInt32,
        ep: UInt32,
        status: Int32,
        actualLength: UInt32,
        startFrame: UInt32 = 0,
        numberOfPackets: UInt32 = 0,
        errorCount: UInt32 = 0,
        transferData: Data? = nil
    ) -> Data {
        let buf = ByteBuffer()
        buf.writeUInt32(USBIPConstants.retSubmit)
        buf.writeUInt32(seqnum)
        buf.writeUInt32(devid)
        buf.writeUInt32(direction)
        buf.writeUInt32(ep)
        buf.writeInt32(status)
        buf.writeUInt32(actualLength)
        buf.writeUInt32(startFrame)
        buf.writeUInt32(numberOfPackets)
        buf.writeUInt32(errorCount)
        buf.writeData(Data(repeating: 0, count: 8)) // 8 bytes setup padding
        
        if direction == USBIPConstants.dirIn, let data = transferData, actualLength > 0 {
            buf.writeData(data.prefix(Int(actualLength)))
        }
        return buf.rawData
    }
}
