// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Settings & Preferences View
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(SwiftUI)
import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var vm: ServerViewModel
    @State private var portString: String = "3240"
    @State private var isLaunchdInstalled: Bool = false
    @State private var autoBoundList: [String] = []

    private let bgDark = Color(red: 0.043, green: 0.047, blue: 0.055)
    private let cardDark = Color(red: 0.075, green: 0.078, blue: 0.090)
    private let neonGreen = Color(red: 0.824, green: 0.973, blue: 0.0)
    private let neonCyan = Color(red: 0.631, green: 0.631, blue: 0.667)
    private let textMuted = Color(red: 0.557, green: 0.569, blue: 0.604)

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Settings & Configuration")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Fine-tune network ports, auto-bind profiles, and launch daemon services.")
                        .font(.system(size: 12))
                        .foregroundColor(textMuted)
                }

                // Network & Daemon Configuration
                VStack(alignment: .leading, spacing: 14) {
                    Label("Network & Server Daemon", systemImage: "network")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(neonCyan)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("TCP Server Port:")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                            Spacer()
                            TextField("3240", text: $portString)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .font(.system(size: 12, design: .monospaced))
                                .onSubmit {
                                    if let p = UInt16(portString) {
                                        vm.serverPort = p
                                    }
                                }
                        }

                        Text("Default USB/IP standard port is 3240. Changing port requires server restart.")
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)

                        Divider().background(Color.white.opacity(0.1))

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Multi-Tier Discovery")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Text("Responds to UDP 3241 subnet broadcasts and advertises via Bonjour/mDNS (_usbanywhere._tcp)")
                                    .font(.system(size: 11))
                                    .foregroundColor(textMuted)
                            }
                            Spacer()
                            Circle()
                                .fill(neonGreen)
                                .frame(width: 10, height: 10)
                            Text("Active")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(neonGreen)
                        }
                    }
                    .padding(14)
                    .background(cardDark)
                    .cornerRadius(10)
                }

                // Background Service (launchd)
                VStack(alignment: .leading, spacing: 14) {
                    Label("macOS Background Service (launchd)", systemImage: "gearshape.2")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(neonCyan)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("com.usbanywhere.server.plist")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Runs the server as a headless system daemon starting automatically on boot.")
                                    .font(.system(size: 11))
                                    .foregroundColor(textMuted)
                            }
                            Spacer()
                            Button(isLaunchdInstalled ? "Uninstall Service" : "Install Service") {
                                toggleLaunchd()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isLaunchdInstalled ? Color.red : Color(red: 0.15, green: 0.35, blue: 0.70))
                        }
                    }
                    .padding(14)
                    .background(cardDark)
                    .cornerRadius(10)
                }

                // Auto-Bind Profiles
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Remembered Auto-Bind Peripherals (\(autoBoundList.count))", systemImage: "pin.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(neonCyan)
                        Spacer()
                        if !autoBoundList.isEmpty {
                            Button("Clear All") {
                                AutoBindManager.shared.clearAll()
                                loadSettings()
                                vm.refreshDevices()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        }
                    }

                    if autoBoundList.isEmpty {
                        HStack {
                            Spacer()
                            Text("No devices marked for auto-bind. Click 'Auto-Bind' on any device card in Dashboard to remember it.")
                                .font(.system(size: 12))
                                .foregroundColor(textMuted)
                                .multilineTextAlignment(.center)
                                .padding(16)
                            Spacer()
                        }
                        .background(cardDark)
                        .cornerRadius(10)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(autoBoundList, id: \.self) { vidPid in
                                HStack {
                                    Text("Device Hardware ID:")
                                        .font(.system(size: 12))
                                        .foregroundColor(textMuted)
                                    Text(vidPid)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(neonGreen)
                                    Spacer()
                                    Button(action: {
                                        _ = AutoBindManager.shared.toggleAutoBind(vidPid: vidPid)
                                        loadSettings()
                                        vm.refreshDevices()
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(10)
                                .background(Color(red: 0.08, green: 0.10, blue: 0.13))
                                .cornerRadius(8)
                            }
                        }
                        .padding(14)
                        .background(cardDark)
                        .cornerRadius(10)
                    }
                }

                // About & Hardware Parity
                VStack(alignment: .leading, spacing: 8) {
                    Label("About USBAnywhere Server for macOS", systemImage: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(neonCyan)

                    Text("USBAnywhere macOS Server is an industrial-grade USB/IP daemon and GUI suite built natively in Swift & AppKit/SwiftUI. Provides feature parity with Windows Server, including IOKit enumeration, dynamic client handshakes, 8000 Hz polling ready, and multi-tier network discovery.")
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color(red: 0.086, green: 0.090, blue: 0.106))
                .cornerRadius(10)
            }
            .padding(20)
        }
        .background(bgDark)
        .onAppear {
            loadSettings()
        }
    }

    private func loadSettings() {
        portString = "\(vm.serverPort)"
        autoBoundList = AutoBindManager.shared.getAutoBoundList()
        let plistPath = "/Library/LaunchDaemons/com.usbanywhere.server.plist"
        isLaunchdInstalled = FileManager.default.fileExists(atPath: plistPath)
    }

    private func toggleLaunchd() {
        if isLaunchdInstalled {
            _ = LaunchdService.uninstall()
        } else {
            _ = LaunchdService.install()
        }
        loadSettings()
    }
}
#endif
