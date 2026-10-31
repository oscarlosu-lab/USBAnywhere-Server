// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - UDP Discovery Responder (Port 3241)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(Darwin)
import Darwin
#endif

public final class DiscoveryResponder {
    public static let shared = DiscoveryResponder()
    private let port: UInt16 = 3241
    private var socketFd: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.usbanywhere.discovery.responder", qos: .utility)

    private init() {}

    public func start() {
        guard !isRunning else { return }
        socketFd = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFd >= 0 else { return }

        var yes: Int32 = 1
        setsockopt(socketFd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        #if os(macOS)
        var reusePort: Int32 = 1
        setsockopt(socketFd, SOL_SOCKET, SO_REUSEPORT, &reusePort, socklen_t(MemoryLayout<Int32>.size))
        #endif

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = in_addr_t(0) // INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            close(socketFd)
            socketFd = -1
            return
        }

        isRunning = true
        queue.async { [weak self] in
            self?.listenLoop()
        }
    }

    private func listenLoop() {
        var buffer = [UInt8](repeating: 0, count: 1024)
        while isRunning && socketFd >= 0 {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let bytesRead = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(socketFd, &buffer, buffer.count, 0, $0, &clientLen)
                }
            }

            guard bytesRead > 0 else { continue }
            let msg = String(decoding: buffer[0..<bytesRead], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if msg.contains("USBANYWHERE_DISCOVERY_PROBE") || msg.contains("DISCOVERY") {
                let hostName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
                let response = "USBANYWHERE_SERVER:\(hostName)\n"
                if let respData = response.data(using: .utf8) {
                    respData.withUnsafeBytes { rawBuf in
                        _ = withUnsafePointer(to: &clientAddr) {
                            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                                sendto(socketFd, rawBuf.baseAddress, respData.count, 0, $0, clientLen)
                            }
                        }
                    }
                }
            }
        }
    }

    public func stop() {
        isRunning = false
        if socketFd >= 0 {
            close(socketFd)
            socketFd = -1
        }
    }
}
