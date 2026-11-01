// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Settings & Preferences View (Obsidian Precision)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(SwiftUI)
import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var vm: ServerViewModel
    @State private var portString: String = "3240"
    @State private var isLaunchdInstalled: Bool = false
    @State private var protectLocalHid: Bool = false
    @State private var autoBoundList: [String] = []

    private let bgDark = Color(red: 0.043, green: 0.047, blue: 0.055)     // #0B0C0E Carbon Obsidian
    private let cardDark = Color(red: 0.075, green: 0.078, blue: 0.090)   // #131417 Surface Elevated
    private let neonGreen = Color(red: 0.824, green: 0.973, blue: 0.0)    // #D2F800 Acid Lime Accent
    private let neonCyan = Color(red: 0.0, green: 0.898, blue: 1.0)       // #00E5FF Electric Cyan
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)  // #A1A1AA Zinc-400

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Settings & Configuration")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Fine-tune network ports, Zero-Host-Lockout policies, and launch daemon services.")
                        .font(.system(size: 12))
                        .foregroundColor(textMuted)
                }

                // Network & Daemon Configuration
                VStack(alignment: .leading, spacing: 14) {
                    Label("Network & Dynamic Control Daemon", systemImage: "network")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(neonCyan)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("TCP USB/IP Port:")
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

                        Text("Default USB/IP standard port is 3240. On-Demand Control API & Discovery use TCP/UDP 3241.")
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)

                        Divider().background(Color.white.opacity(0.1))

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Multi-Tier Discovery & Dynamic Auto-Unbind")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Text("Listens on TCP/UDP 3241, advertises via Bonjour (_usbanywhere._tcp), and releases devices on disconnect")
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

                        Divider().background(Color.white.opacity(0.1))

                        Toggle(isOn: $protectLocalHid) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Protect Local HID Peripherals")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                Text("Prevents remote clients from grabbing local keyboards, mice, or gamepads")
                                    .font(.system(size: 11))
                                    .foregroundColor(textMuted)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(neonGreen)
                        .onChange(of: protectLocalHid) { newValue in
                            IOKitDeviceManager.shared.updatePolicy(protectLocalHid: newValue)
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
                            Button(action: { toggleLaunchd() }) {
                                Text(isLaunchdInstalled ? "Uninstall Service" : "Install Service")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isLaunchdInstalled ? .white : .black)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isLaunchdInstalled ? Color(red: 0.30, green: 0.12, blue: 0.12) : neonGreen)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.red)
                        }
                    }

                    if autoBoundList.isEmpty {
                        HStack {
                            Spacer()
                            Text("No devices pinned for static auto-bind. All devices use On-Demand Dynamic Binding by default.")
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
                                .background(Color(red: 0.055, green: 0.060, blue: 0.072))
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
                    Label("About USBAnywhere Server for macOS v3.2.0", systemImage: "info.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(neonCyan)

                    Text("USBAnywhere macOS Server is an industrial-grade USB/IP daemon and GUI suite built natively in Swift & AppKit/SwiftUI. Provides full feature parity with Windows and Linux servers, including IOKit composite interface enumeration, TCP 3241 On-Demand Control API, Zero-Host-Lockout auto-unbind, and multi-tier network discovery.")
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
        autoBoundList = Array(AutoBindManager.shared.getAutoBoundList()).sorted()
        protectLocalHid = IOKitDeviceManager.shared.getState().protectLocalHid
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
