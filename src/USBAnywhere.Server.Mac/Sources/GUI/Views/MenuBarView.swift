// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Menu Bar Extra View
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(SwiftUI)
import SwiftUI

public struct MenuBarView: View {
    @EnvironmentObject var vm: ServerViewModel
    var onOpenDashboard: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    private let neonGreen = Color(red: 0.824, green: 0.973, blue: 0.0)
    private let neonCyan = Color(red: 0.631, green: 0.631, blue: 0.667)
    private let textMuted = Color(red: 0.557, green: 0.569, blue: 0.604)

    public init(onOpenDashboard: @escaping () -> Void = {}, onOpenSettings: @escaping () -> Void = {}) {
        self.onOpenDashboard = onOpenDashboard
        self.onOpenSettings = onOpenSettings
    }

    private var sharedCount: Int {
        vm.devices.filter { $0.isBound }.count
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header / Status
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.isServerActive ? neonGreen : Color.red)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("USBAnywhere Server")
                        .font(.system(size: 13, weight: .bold))
                    Text(vm.isServerActive ? "Running on port \(vm.serverPort)" : "Server Stopped")
                        .font(.system(size: 11))
                        .foregroundColor(vm.isServerActive ? neonGreen : textMuted)
                }
                
                Spacer()
                
                Button(action: { vm.toggleServer() }) {
                    Text(vm.isServerActive ? "Stop" : "Start")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(vm.isServerActive ? Color.red : neonGreen)
            }
            .padding(.bottom, 4)

            Divider()

            // IP Address & Quick Copy
            HStack {
                Label("\(vm.primaryIpAddress):\(vm.serverPort)", systemImage: "network")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(neonCyan)
                
                Spacer()
                
                Button(action: { vm.copyIpToClipboard() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Copy IP to clipboard")
            }

            Divider()

            // Exported Devices Summary
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Shared Peripherals (\(sharedCount)/\(vm.devices.count))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(textMuted)
                    Spacer()
                    if sharedCount > 0 {
                        Button("Stop All") {
                            vm.stopAll()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    } else if !vm.devices.isEmpty {
                        Button("Share All") {
                            vm.shareAll()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(neonGreen)
                    }
                }

                if sharedCount == 0 {
                    Text("No USB devices currently exported")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    ForEach(vm.devices.filter { $0.isBound }.prefix(4)) { dev in
                        HStack(spacing: 6) {
                            Text(dev.categoryEmoji)
                                .font(.system(size: 12))
                            Text(dev.productName ?? "USB Device")
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                            Text("[\(dev.busId)]")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(neonCyan)
                        }
                    }
                    if sharedCount > 4 {
                        Text("+ \(sharedCount - 4) more devices...")
                            .font(.system(size: 10))
                            .foregroundColor(textMuted)
                    }
                }
            }

            Divider()

            // Navigation and Actions
            Button(action: onOpenDashboard) {
                Label("Open Dashboard Window...", systemImage: "macwindow")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)

            Button(action: onOpenSettings) {
                Label("Preferences...", systemImage: "gearshape")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)

            Divider()

            Button(role: .destructive, action: {
                #if os(macOS)
                NSApplication.shared.terminate(nil)
                #else
                exit(0)
                #endif
            }) {
                Label("Quit USBAnywhere Server", systemImage: "power")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 280)
    }
}
#endif
