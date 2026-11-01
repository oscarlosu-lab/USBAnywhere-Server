// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Menu Bar Extra View (Obsidian Precision)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(SwiftUI)
import SwiftUI

public struct MenuBarView: View {
    @EnvironmentObject var vm: ServerViewModel
    var onOpenDashboard: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    private let bgDark = Color(red: 0.043, green: 0.047, blue: 0.055)     // #0B0C0E Carbon Obsidian
    private let cardDark = Color(red: 0.075, green: 0.078, blue: 0.090)   // #131417 Elevated Surface
    private let neonGreen = Color(red: 0.824, green: 0.973, blue: 0.0)    // #D2F800 Acid Lime Accent
    private let neonCyan = Color(red: 0.0, green: 0.898, blue: 1.0)       // #00E5FF Electric Cyan
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)  // #A1A1AA Zinc-400

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
                        .foregroundColor(.white)
                    Text(vm.isServerActive ? "Running on port \(vm.serverPort)" : "Server Stopped")
                        .font(.system(size: 11))
                        .foregroundColor(vm.isServerActive ? neonGreen : textMuted)
                }
                
                Spacer()
                
                Button(action: { vm.toggleServer() }) {
                    Text(vm.isServerActive ? "Stop" : "Start")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(vm.isServerActive ? .white : .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(vm.isServerActive ? Color(red: 0.30, green: 0.12, blue: 0.12) : neonGreen)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(vm.isServerActive ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            Divider().background(Color.white.opacity(0.1))

            // IP Address & Quick Copy
            HStack {
                Label("\(vm.primaryIpAddress):\(vm.serverPort)", systemImage: "network")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(neonCyan)
                
                Spacer()
                
                Button(action: { vm.copyIpToClipboard() }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                }
                .buttonStyle(.plain)
                .help("Copy IP to clipboard")
            }

            Divider().background(Color.white.opacity(0.1))

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
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.red)
                    } else if !vm.devices.isEmpty {
                        Button("Share All") {
                            vm.shareAll()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(neonGreen)
                    }
                }

                if sharedCount == 0 {
                    Text("On-Demand active (0 statically exported)")
                        .font(.system(size: 11))
                        .foregroundColor(textMuted)
                        .italic()
                } else {
                    ForEach(vm.devices.filter { $0.isBound }.prefix(4)) { dev in
                        HStack(spacing: 6) {
                            Text(dev.categoryEmoji)
                                .font(.system(size: 12))
                            Text(dev.cleanProductName)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
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

            Divider().background(Color.white.opacity(0.1))

            // Navigation and Actions
            Button(action: onOpenDashboard) {
                Label("Open Dashboard Window...", systemImage: "macwindow")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Button(action: onOpenSettings) {
                Label("Preferences...", systemImage: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Divider().background(Color.white.opacity(0.1))

            Button(role: .destructive, action: {
                #if os(macOS)
                NSApplication.shared.terminate(nil)
                #else
                exit(0)
                #endif
            }) {
                Label("Quit USBAnywhere Server", systemImage: "power")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 290)
        .background(bgDark)
    }
}
#endif
