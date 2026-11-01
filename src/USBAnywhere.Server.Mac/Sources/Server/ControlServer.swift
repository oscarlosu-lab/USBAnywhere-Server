// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Dynamic Control Server (TCP Port 3241)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class ControlServer {
    public static let shared = ControlServer()
    public static let defaultControlPort: UInt16 = 3241

    private var serverSocket: Int32 = -1
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "com.usbanywhere.server.mac.control", attributes: .concurrent)

    private init() {}

    public func start(port: UInt16 = ControlServer.defaultControlPort) {
        guard !isRunning else { return }

        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { return }

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
            serverSocket = -1
            return
        }

        guard listen(serverSocket, 8) == 0 else {
            close(serverSocket)
            serverSocket = -1
            return
        }

        isRunning = true
        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    public func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    private func acceptLoop() {
        while isRunning && serverSocket >= 0 {
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

            queue.async { [weak self] in
                self?.handleClient(fd: clientFd)
            }
        }
    }

    private func handleClient(fd: Int32) {
        defer { close(fd) }

        var buffer = [UInt8](repeating: 0, count: 1024)
        let bytesRead = recv(fd, &buffer, buffer.count, 0)
        guard bytesRead > 0 else { return }

        let rawCommand = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
        let response = Self.processCommand(rawCommand)
        if let data = (response + "\n").data(using: .utf8) {
            _ = data.withUnsafeBytes { rawBuf in
                send(fd, rawBuf.baseAddress, data.count, 0)
            }
        }
    }

    /// Processes a single control command and returns a JSON response line
    public static func processCommand(_ rawInput: String) -> String {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return #"{"status": "ERROR", "message": "Empty command"}"#
        }

        let parts = trimmed.split(separator: " ").map(String.init)
        let cmd = parts[0].uppercased()

        switch cmd {
        case "LIST":
            let devices = IOKitDeviceManager.shared.enumerateDevices()
            let lines = devices.map { $0.dynamicInventoryLine }
            let payload: [String: Any] = [
                "status": "OK",
                "devices": lines
            ]
            return encodeJSON(payload)

        case "BIND":
            guard parts.count >= 2 else {
                return #"{"status": "ERROR", "message": "Missing busid"}"#
            }
            let targetBus = parts[1]
            let check = IOKitDeviceManager.shared.isDeviceExportAllowed(busId: targetBus)
            if !check.allowed {
                return encodeJSON([
                    "status": "DENIED",
                    "busid": targetBus,
                    "action": "bind",
                    "message": check.reason
                ])
            }
            let ok = IOKitDeviceManager.shared.bindDevice(busId: targetBus, dynamic: true)
            return encodeJSON([
                "status": ok ? "OK" : "ERROR",
                "busid": targetBus,
                "action": "bind"
            ])

        case "UNBIND":
            guard parts.count >= 2 else {
                return #"{"status": "ERROR", "message": "Missing busid"}"#
            }
            let targetBus = parts[1]
            let ok = IOKitDeviceManager.shared.unbindDevice(busId: targetBus)
            return encodeJSON([
                "status": ok ? "OK" : "ERROR",
                "busid": targetBus,
                "action": "unbind"
            ])

        case "STATUS":
            let devices = IOKitDeviceManager.shared.enumerateDevices()
            let devList: [[String: Any]] = devices.map { dev in
                [
                    "busid": dev.busId,
                    "vid_pid": dev.vidPidString,
                    "name": dev.displayName,
                    "bound": dev.isBound,
                    "connected_clients": dev.isClaimed ? 1 : 0
                ]
            }
            let payload: [String: Any] = [
                "status": "OK",
                "running": true,
                "port_active": true,
                "service_manager": "launchd",
                "devices": devList
            ]
            return encodeJSON(payload)

        case "POLICY":
            let st = IOKitDeviceManager.shared.getState()
            let pol: [String: Any] = [
                "allow_all": st.allowAll,
                "allowlist": st.allowlist,
                "denylist": st.denylist,
                "protect_local_hid": st.protectLocalHid,
                "skip_classes": ["09"]
            ]
            return encodeJSON(["status": "OK", "policy": pol])

        default:
            return #"{"status": "ERROR", "message": "Unknown command"}"#
        }
    }

    private static func encodeJSON(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let str = String(data: data, encoding: .utf8) else {
            return #"{"status": "ERROR", "message": "Serialization failed"}"#
        }
        return str
    }
}
