// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Virtual UAC1 Microphone Device (48kHz PCM)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

public final class VirtualMacMicDevice {
    public let sampleRate: Int = 48_000
    public let channels: Int = 1
    public let bitsPerSample: Int = 16
    public let frameBytesPerMs: Int = 96 // 48000 * 1 * 2 / 1000

    private let lock = NSLock()
    private var ringBuffer = Data()
    private let maxBufferBytes = 48_000 * 2 // 1 second ring buffer
    public private(set) var isCapturing: Bool = false

    #if canImport(AVFoundation)
    private var audioEngine: AVAudioEngine?
    #endif

    public init() {}

    public func startCapture() -> Bool {
        #if canImport(AVFoundation)
        if isCapturing { return true }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let hwFormat = input.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0 else { return false }

        input.installTap(onBus: 0, bufferSize: 960, format: hwFormat) { [weak self] buffer, _ in
            guard let self = self, let ch0 = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            var pcm = Data(capacity: frameCount * 2)
            for i in 0..<frameCount {
                let clamped = max(-1.0, min(1.0, ch0[i]))
                var sample = Int16(clamped * Float(Int16.max)).littleEndian
                withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
            }
            self.pushPcmFrame(pcm)
        }
        do {
            try engine.start()
            self.audioEngine = engine
            self.isCapturing = true
            return true
        } catch {
            input.removeTap(onBus: 0)
            return false
        }
        #else
        return false
        #endif
    }

    public func stopCapture() {
        #if canImport(AVFoundation)
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            audioEngine = nil
        }
        #endif
        isCapturing = false
    }

    public func buildDeviceDescriptor() -> Data {
        return Data([
            18, 1,          // bLength, bDescriptorType (Device)
            0x00, 0x02,     // bcdUSB 2.00
            0x00, 0x00, 0x00,
            64,             // bMaxPacketSize0
            0x09, 0x12,     // idVendor (Generic Open VID)
            0x55, 0x41,     // idProduct ("UA")
            0x00, 0x01,     // bcdDevice 1.00
            1, 2, 0, 1
        ])
    }

    public func buildUac1ConfigDescriptor() -> Data {
        // Minimal UAC1 AudioControl (class 0x01, subclass 0x01) + AudioStreaming (class 0x01, subclass 0x02)
        return Data([
            9, 2, 36, 0, 2, 1, 0, 0x80, 50,
            9, 4, 0, 0, 0, 0x01, 0x01, 0x00, 0, // AudioControl interface
            9, 4, 1, 0, 0, 0x01, 0x02, 0x00, 0, // AudioStreaming alt 0
            9, 4, 1, 1, 1, 0x01, 0x02, 0x00, 0  // AudioStreaming alt 1 (1 iso IN ep)
        ])
    }

    public func pushPcmFrame(_ pcm: Data) {
        lock.lock()
        defer { lock.unlock() }
        ringBuffer.append(pcm)
        if ringBuffer.count > maxBufferBytes {
            ringBuffer.removeFirst(ringBuffer.count - maxBufferBytes)
        }
    }

    public func readFrame(byteCount: Int) -> Data {
        lock.lock()
        defer { lock.unlock() }
        let take = min(byteCount, ringBuffer.count)
        if take > 0 {
            let out = ringBuffer.prefix(take)
            ringBuffer.removeFirst(take)
            return Data(out)
        }
        return Data(repeating: 0, count: byteCount)
    }
}
