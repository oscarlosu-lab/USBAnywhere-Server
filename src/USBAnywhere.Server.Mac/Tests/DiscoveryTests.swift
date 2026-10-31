// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Discovery & Models Unit Tests
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import XCTest
@testable import USBAnywhereServerMac

final class DiscoveryTests: XCTestCase {

    func testDeviceCategoryAndEmoji() {
        let hidDev = USBDeviceInfo(
            busId: "1-1",
            path: "/usb/1-1",
            busNum: 1,
            devNum: 1,
            speed: USBIPConstants.speedHigh,
            idVendor: 0x0BDA,
            idProduct: 0x5100,
            bcdDevice: 0x0100,
            bDeviceClass: 0x0E, // Video class (e.g. Webcam)
            bDeviceSubClass: 0,
            bDeviceProtocol: 0,
            bConfigurationValue: 1,
            bNumConfigurations: 1,
            bNumInterfaces: 1,
            productName: "Realtek USB Camera"
        )

        XCTAssertEqual(hidDev.category, "Video")
        XCTAssertEqual(hidDev.categoryEmoji, "📷")
        XCTAssertEqual(hidDev.speedLabel, "High Speed (480 Mb/s)")
        XCTAssertEqual(hidDev.vidPidString, "0BDA:5100")
        XCTAssertEqual(hidDev.id, "1-1")
    }

    func testAutoBindPersistence() {
        let testVidPid = "9999:AAAA"
        AutoBindManager.shared.clearAll()
        XCTAssertFalse(AutoBindManager.shared.isAutoBound(vidPid: testVidPid))

        let added = AutoBindManager.shared.toggleAutoBind(vidPid: testVidPid)
        XCTAssertTrue(added)
        XCTAssertTrue(AutoBindManager.shared.isAutoBound(vidPid: testVidPid))

        let removed = AutoBindManager.shared.toggleAutoBind(vidPid: testVidPid)
        XCTAssertFalse(removed)
        XCTAssertFalse(AutoBindManager.shared.isAutoBound(vidPid: testVidPid))
    }

    func testDiscoveryResponsePayloadFormat() {
        let hostName = ProcessInfo.processInfo.hostName
        let expectedPrefix = "USBANYWHERE_SERVER:"
        let responseString = "\(expectedPrefix)\(hostName)"
        let responseData = responseString.data(using: .utf8)

        XCTAssertNotNil(responseData)
        XCTAssertTrue(responseString.hasPrefix(expectedPrefix))
        XCTAssertGreaterThan(responseData!.count, expectedPrefix.count)
    }
}
