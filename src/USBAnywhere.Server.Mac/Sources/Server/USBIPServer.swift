// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - POSIX TCP Server (Port 3240)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class USBIPServer {
    private let port: UInt16
    private var serverSocket: Int32 = -1
    private var isRunning: Bool = false
    private let dispatchQueue = DispatchQueue(label: "com.usbanywhere.server.mac", attributes: .concurrent)
    
    public init(port: UInt16 = USBIPConstants.defaultPort) {
        self.port = port
    }
    
    public func start() throws {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw NSError(domain: "USBIPServer", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to create socket"])
        }
        
        var yes: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = in_addr_t(0) // INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            close(serverSocket)
            throw NSError(domain: "USBIPServer", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to bind to port \(port) (requires sudo or port already in use)"])
        }
        
        guard listen(serverSocket, 10) == 0 else {
            close(serverSocket)
            throw NSError(domain: "USBIPServer", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Failed to listen on socket"])
        }
        
        isRunning = true
        print("🌐 USBAnywhere Server (macOS) listening on 0.0.0.0:\(port)")
        print("   Ready for connections from USBAnywhere Client or Linux clients.")
        
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientLen)
                }
            }
            
            guard clientFd >= 0 else {
                if !isRunning { break }
                continue
            }
            
            let clientIP = String(cString: inet_ntoa(clientAddr.sin_addr))
            print("📡 Client connected from \(clientIP)")
            
            dispatchQueue.async {
                self.handleClient(fd: clientFd, clientIP: clientIP)
            }
        }
    }
    
    public func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }
    
    private func handleClient(fd: Int32, clientIP: String) {
        defer {
            close(fd)
            print("🔌 Client disconnected: \(clientIP)")
        }
        
        // 1. Management Handshake Loop
        while isRunning {
            guard let headerData = readExact(fd: fd, count: 4) else { return }
            let buf = ByteBuffer(data: headerData)
            guard let version = buf.readUInt16(),
                  let command = buf.readUInt16() else { return }
            
            if command == USBIPConstants.opReqDevlist {
                handleDevlist(fd: fd, version: version)
            } else if command == USBIPConstants.opReqImport {
                let success = handleImport(fd: fd, version: version)
                if success {
                    // Transition to URB streaming loop for the imported device
                    return
                }
            } else {
                print("⚠️ Unknown management command opcode: \(String(format: "0x%04X", command))")
                return
            }
        }
    }
    
    private func handleDevlist(fd: Int32, version: UInt16) {
        // Read remaining 4 bytes status of OP_REQ_DEVLIST header
        _ = readExact(fd: fd, count: 4)
        
        let allDevices = IOKitDeviceManager.shared.enumerateDevices()
        let exportedDevices = allDevices.filter { $0.isBound }
        
        print("📋 Sending device list: \(exportedDevices.count) exported devices")
        let replyData = USBIPPackets.encodeDevlistReply(devices: exportedDevices)
        _ = writeExact(fd: fd, data: replyData)
    }
    
    private func handleImport(fd: Int32, version: UInt16) -> Bool {
        // Read 4 bytes status + 32 bytes busid
        guard let payload = readExact(fd: fd, count: 4 + USBIPConstants.maxBusIdLength) else { return false }
        let buf = ByteBuffer(data: payload)
        _ = buf.readUInt32() // status
        guard let requestedBusId = buf.readFixedString(length: USBIPConstants.maxBusIdLength) else { return false }
        
        let allDevices = IOKitDeviceManager.shared.enumerateDevices()
        guard let targetDev = allDevices.first(where: { $0.busId == requestedBusId && $0.isBound }) else {
            print("❌ Requested busid '\(requestedBusId)' not found or not bound.")
            let errReply = USBIPPackets.encodeImportReply(device: nil, status: USBIPConstants.statusError)
            _ = writeExact(fd: fd, data: errReply)
            return false
        }
        
        print("🔗 Attaching device [\(targetDev.busId)] \(targetDev.displayName)...")
        targetDev.isClaimed = true
        let okReply = USBIPPackets.encodeImportReply(device: targetDev, status: USBIPConstants.statusOk)
        _ = writeExact(fd: fd, data: okReply)
        
        // Enter URB processing loop
        enterURBLoop(fd: fd, device: targetDev)
        targetDev.isClaimed = false
        return true
    }
    
    private func enterURBLoop(fd: Int32, device: USBDeviceInfo) {
        let handler = URBHandler(device: device)
        print("⚡ Active URB streaming session started for [\(device.busId)]")
        
        while isRunning {
            // Read USBIP Command Header (48 bytes)
            guard let headerData = readExact(fd: fd, count: 48) else { break }
            let buf = ByteBuffer(data: headerData)
            guard let cmdType = buf.readUInt32() else { break }
            
            if cmdType == USBIPConstants.cmdSubmit {
                guard let cmd = USBIPPackets.CmdSubmit.decode(from: buf) else { break }
                
                // If OUT transfer, read payload buffer
                var fullCmd = cmd
                if cmd.direction == USBIPConstants.dirOut && cmd.transferBufferLength > 0 {
                    guard let outData = readExact(fd: fd, count: Int(cmd.transferBufferLength)) else { break }
                    fullCmd = USBIPPackets.CmdSubmit(
                        seqnum: cmd.seqnum, devid: cmd.devid, direction: cmd.direction,
                        ep: cmd.ep, transferFlags: cmd.transferFlags,
                        transferBufferLength: cmd.transferBufferLength,
                        startFrame: cmd.startFrame, numberOfPackets: cmd.numberOfPackets,
                        interval: cmd.interval, setup: cmd.setup, transferBuffer: outData
                    )
                }
                
                let retPacket = handler.handleSubmit(cmd: fullCmd)
                guard writeExact(fd: fd, data: retPacket) else { break }
                
            } else if cmdType == USBIPConstants.cmdUnlink {
                // USBIP_CMD_UNLINK
                guard let seqnum = buf.readUInt32(),
                      let devid = buf.readUInt32(),
                      let _ = buf.readUInt32(),
                      let ep = buf.readUInt32(),
                      let _ = buf.readUInt32() else { break }
                
                // Return RET_UNLINK
                let retBuf = ByteBuffer()
                retBuf.writeUInt32(USBIPConstants.retUnlink)
                retBuf.writeUInt32(seqnum)
                retBuf.writeUInt32(devid)
                retBuf.writeUInt32(0) // direction
                retBuf.writeUInt32(ep)
                retBuf.writeInt32(0)  // status OK
                retBuf.writeData(Data(repeating: 0, count: 28)) // padding
                guard writeExact(fd: fd, data: retBuf.rawData) else { break }
            } else {
                print("⚠️ Unknown URB command type: \(cmdType)")
                break
            }
        }
        print("🛑 URB streaming session ended for [\(device.busId)]")
    }
    
    // MARK: - Low-level I/O Helpers
    private func readExact(fd: Int32, count: Int) -> Data? {
        var result = Data(count: count)
        var totalRead = 0
        
        while totalRead < count {
            let bytesRemaining = count - totalRead
            let bytesRead = result.withUnsafeMutableBytes { ptr -> Int in
                guard let base = ptr.baseAddress else { return -1 }
                return read(fd, base.advanced(by: totalRead), bytesRemaining)
            }
            if bytesRead <= 0 { return nil }
            totalRead += bytesRead
        }
        return result
    }
    
    private func writeExact(fd: Int32, data: Data) -> Bool {
        var totalWritten = 0
        let count = data.count
        
        while totalWritten < count {
            let bytesRemaining = count - totalWritten
            let bytesWritten = data.withUnsafeBytes { ptr -> Int in
                guard let base = ptr.baseAddress else { return -1 }
                return write(fd, base.advanced(by: totalWritten), bytesRemaining)
            }
            if bytesWritten <= 0 { return false }
            totalWritten += bytesWritten
        }
        return true
    }
}
