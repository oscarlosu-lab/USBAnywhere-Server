// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - USB/IP Protocol Constants
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

public enum USBIPConstants {
    /// Default USB/IP TCP listening port
    public static let defaultPort: UInt16 = 3240
    
    /// USB/IP Protocol Version (0x0111 = 1.1.1)
    public static let protocolVersion: UInt16 = 0x0111
    
    // MARK: - Management Command Opcodes
    public static let opReqDevlist: UInt16 = 0x8005
    public static let opRepDevlist: UInt16 = 0x0005
    public static let opReqImport: UInt16  = 0x8003
    public static let opRepImport: UInt16  = 0x0003
    
    // MARK: - URB Transfer Commands
    public static let cmdSubmit: UInt32 = 0x0000_0001
    public static let retSubmit: UInt32 = 0x0000_0003
    public static let cmdUnlink: UInt32 = 0x0000_0002
    public static let retUnlink: UInt32 = 0x0000_0004
    
    // MARK: - Status Codes
    public static let statusOk: UInt32    = 0x0000_0000
    public static let statusError: UInt32 = 0x0000_0001
    public static let statusBusy: UInt32  = 0x0000_0002
    
    // MARK: - Transfer Directions
    public static let dirOut: UInt32 = 0
    public static let dirIn: UInt32  = 1
    
    // MARK: - USB Speeds
    public static let speedUnknown: UInt32 = 0
    public static let speedLow: UInt32     = 1  // 1.5 Mbps
    public static let speedFull: UInt32    = 2  // 12 Mbps
    public static let speedHigh: UInt32    = 3  // 480 Mbps
    public static let speedWireless: UInt32 = 4
    public static let speedSuper: UInt32   = 5  // 5 Gbps
    public static let speedSuperPlus: UInt32 = 6 // 10+ Gbps
    
    // MARK: - Buffer Sizes
    public static let maxBusIdLength: Int = 32
    public static let maxPathLength: Int  = 256
}
