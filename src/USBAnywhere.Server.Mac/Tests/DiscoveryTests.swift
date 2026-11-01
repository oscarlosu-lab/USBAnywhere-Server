// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Discovery, Policy & Control API Unit Tests
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import XCTest
@testable import USBAnywhereServerMac

final class DiscoveryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        IOKitDeviceManager.shared.resetState()
    }

    func testDeviceCategoryAndEmoji() {
        let videoDev = USBDeviceInfo(
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

        XCTAssertEqual(videoDev.category, "Video")
        XCTAssertEqual(videoDev.categoryEmoji, "📷")
        XCTAssertEqual(videoDev.speedLabel, "High Speed (480 Mb/s)")
        XCTAssertEqual(videoDev.vidPidString, "0BDA:5100")
        XCTAssertEqual(videoDev.id, "1-1")
        XCTAssertEqual(videoDev.dynamicInventoryLine, "  1-1    : Realtek USB Camera [Video] (0bda:5100)")
    }

    func testCompositeSteamControllerRecognition() {
        let steamPuck = USBDeviceInfo(
            busId: "1-2",
            path: "/usb/1-2",
            busNum: 1,
            devNum: 2,
            speed: USBIPConstants.speedFull,
            idVendor: 0x28DE,
            idProduct: 0x1304,
            bcdDevice: 0x0100,
            bDeviceClass: 0xEF, // Miscellaneous composite class
            bDeviceSubClass: 0x02,
            bDeviceProtocol: 0x01,
            bConfigurationValue: 1,
            bNumConfigurations: 1,
            bNumInterfaces: 2,
            interfaces: [
                USBInterfaceInfo(interfaceClass: 0x03, interfaceSubClass: 0, interfaceProtocol: 0),
                USBInterfaceInfo(interfaceClass: 0x03, interfaceSubClass: 0, interfaceProtocol: 0)
            ]
        )

        XCTAssertTrue(steamPuck.isSteamController)
        XCTAssertTrue(steamPuck.isHid)
        XCTAssertFalse(steamPuck.isHub)
        XCTAssertEqual(steamPuck.category, "HID / Gaming")
        XCTAssertEqual(steamPuck.categoryTag, " [HID/Gamepad]")
        XCTAssertTrue(steamPuck.dynamicInventoryLine.contains("[HID/Gamepad] (28de:1304)"))
    }

    func testSharedStateAndExportPolicy() {
        // Test cross-process shared state bind / unbind
        XCTAssertTrue(IOKitDeviceManager.shared.bindDevice(busId: "2-1", dynamic: true))
        XCTAssertTrue(IOKitDeviceManager.shared.isBound(busId: "2-1"))
        XCTAssertTrue(IOKitDeviceManager.shared.isDynamicBound(busId: "2-1"))
        XCTAssertTrue(IOKitDeviceManager.shared.unbindDevice(busId: "2-1"))
        XCTAssertFalse(IOKitDeviceManager.shared.isBound(busId: "2-1"))

        // Test Denylist Policy via ControlServer
        IOKitDeviceManager.shared.updatePolicy(denylist: ["3-4", "28de:1304"])
        let deniedResp = ControlServer.processCommand("BIND 3-4")
        XCTAssertTrue(deniedResp.contains(#""status":"DENIED""#) || deniedResp.contains(#""status": "DENIED""#))

        // Test Allow via ControlServer
        IOKitDeviceManager.shared.updatePolicy(denylist: [])
        let okResp = ControlServer.processCommand("BIND 3-4")
        XCTAssertTrue(okResp.contains(#""status":"OK""#) || okResp.contains(#""status": "OK""#))
        XCTAssertTrue(IOKitDeviceManager.shared.isBound(busId: "3-4"))

        let unbindResp = ControlServer.processCommand("UNBIND 3-4")
        XCTAssertTrue(unbindResp.contains(#""status":"OK""#) || unbindResp.contains(#""status": "OK""#))
        XCTAssertFalse(IOKitDeviceManager.shared.isBound(busId: "3-4"))
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
