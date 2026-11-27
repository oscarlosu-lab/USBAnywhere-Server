// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - IOUSBHost Real User-Space USB Transport
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

public protocol USBDeviceTransport {
    func controlTransfer(
        bmRequestType: UInt8,
        bRequest: UInt8,
        wValue: UInt16,
        wIndex: UInt16,
        data: Data?,
        maxLength: Int
    ) -> Data?

    func bulkOrInterruptTransfer(
        endpoint: UInt8,
        direction: UInt32,
        data: Data?,
        maxLength: Int
    ) -> Data?

    func close()
}

#if canImport(IOUSBHost)
import IOKit
import IOUSBHost

public final class IOUSBHostSession: USBDeviceTransport {
    private let device: IOUSBHostDevice?
    private let queue = DispatchQueue(label: "com.usbanywhere.iousbhost")
    private var interfaces: [IOUSBHostInterface] = []
    private var pipes: [UInt8: IOUSBHostPipe] = [:]
    private let lock = NSLock()

    public init?(ioService: io_service_t, interfaceServices: [io_service_t] = []) {
        do {
            self.device = try IOUSBHostDevice(__ioService: ioService, options: [.deviceCapture], queue: queue, interestHandler: nil)
            for intfSvc in interfaceServices {
                if let intf = try? IOUSBHostInterface(__ioService: intfSvc, options: [.deviceCapture], queue: queue, interestHandler: nil) {
                    interfaces.append(intf)
                }
            }
        } catch {
            return nil
        }
    }

    public func controlTransfer(
        bmRequestType: UInt8,
        bRequest: UInt8,
        wValue: UInt16,
        wIndex: UInt16,
        data: Data?,
        maxLength: Int
    ) -> Data? {
        guard let dev = device else { return nil }
        let request = IOUSBDeviceRequest(
            bmRequestType: bmRequestType,
            bRequest: bRequest,
            wValue: wValue,
            wIndex: wIndex,
            wLength: UInt16(min(maxLength, 4096))
        )
        var bytesTransferred = 0
        if (bmRequestType & 0x80) != 0 {
            guard let buffer = NSMutableData(length: max(1, maxLength)) else { return nil }
            do {
                try dev.__send(request, data: buffer, bytesTransferred: &bytesTransferred, completionTimeout: 1.5)
                return Data(bytes: buffer.bytes, count: max(0, bytesTransferred))
            } catch {
                return nil
            }
        } else {
            let outBuf = data.map { NSMutableData(data: $0) }
            do {
                try dev.__send(request, data: outBuf, bytesTransferred: &bytesTransferred, completionTimeout: 1.5)
                return Data()
            } catch {
                return nil
            }
        }
    }

    private func resolvePipe(endpointAddress: UInt8) -> IOUSBHostPipe? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = pipes[endpointAddress] {
            return cached
        }
        for intf in interfaces {
            if let pipe = try? intf.copyPipe(withAddress: Int(endpointAddress)) {
                pipes[endpointAddress] = pipe
                return pipe
            }
        }
        return nil
    }

    public func bulkOrInterruptTransfer(
        endpoint: UInt8,
        direction: UInt32,
        data: Data?,
        maxLength: Int
    ) -> Data? {
        let epAddr: UInt8 = direction == 1 ? (endpoint | 0x80) : (endpoint & 0x7F)
        guard let pipe = resolvePipe(endpointAddress: epAddr) else {
            return nil
        }
        var bytesTransferred = 0
        if direction == 1 {
            guard let buf = NSMutableData(length: max(1, maxLength)) else { return nil }
            let sem = DispatchSemaphore(value: 0)
            var ioStatus: IOReturn = kIOReturnError
            var transferred: Int = 0
            do {
                try pipe.enqueueIORequest(with: buf, completionTimeout: 1.5) { status, bytes in
                    ioStatus = status
                    transferred = bytes
                    sem.signal()
                }
                if sem.wait(timeout: .now() + 2.0) == .success && ioStatus == kIOReturnSuccess {
                    return Data(bytes: buf.bytes, count: max(0, min(transferred, buf.length)))
                }
            } catch {
                return nil
            }
        } else if let outData = data {
            let buf = NSMutableData(data: outData)
            let sem = DispatchSemaphore(value: 0)
            var ioStatus: IOReturn = kIOReturnError
            do {
                try pipe.enqueueIORequest(with: buf, completionTimeout: 1.5) { status, _ in
                    ioStatus = status
                    sem.signal()
                }
                if sem.wait(timeout: .now() + 2.0) == .success && ioStatus == kIOReturnSuccess {
                    return Data()
                }
            } catch {
                return nil
            }
        }
        return nil
    }

    public func close() {
        lock.lock()
        pipes.removeAll()
        for intf in interfaces {
            intf.destroy()
        }
        interfaces.removeAll()
        lock.unlock()
        device?.destroy()
    }
}
#endif
