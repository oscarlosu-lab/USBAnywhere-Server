// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - SwiftUI Dashboard View (Obsidian Precision)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(SwiftUI)
import SwiftUI

public struct ServerDashboardView: View {
    @EnvironmentObject var vm: ServerViewModel
    @State private var showingLogs = true

    private let bgDark = Color(red: 0.043, green: 0.047, blue: 0.055)     // #0B0C0E Carbon Obsidian
    private let cardDark = Color(red: 0.075, green: 0.078, blue: 0.090)   // #131417 Surface Elevated
    private let neonGreen = Color(red: 0.824, green: 0.973, blue: 0.0)    // #D2F800 Acid Lime Accent
    private let neonCyan = Color(red: 0.0, green: 0.898, blue: 1.0)       // #00E5FF Electric Cyan
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)  // #A1A1AA Zinc-400

    public init() {}

    private var filteredDevices: [USBDeviceInfo] {
        if vm.searchText.isEmpty {
            return vm.devices
        } else {
            return vm.devices.filter {
                $0.displayName.localizedCaseInsensitiveContains(vm.searchText) ||
                $0.vidPidString.localizedCaseInsensitiveContains(vm.searchText) ||
                $0.busId.localizedCaseInsensitiveContains(vm.searchText)
            }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerSection
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color(red: 0.086, green: 0.090, blue: 0.106))

            Divider().background(Color.white.opacity(0.1))

            // Main Content Area
            HSplitView {
                // Device List Panel
                VStack(spacing: 12) {
                    toolbarSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    if filteredDevices.isEmpty {
                        emptyStateSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredDevices) { device in
                                    DeviceCardRow(device: device)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
                .frame(minWidth: 440)

                // Live Logs Panel
                if showingLogs {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Live Server Activity", systemImage: "terminal.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(neonCyan)
                            Spacer()
                            Button("Clear") {
                                vm.logs.removeAll()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(textMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)

                        Divider().background(Color.white.opacity(0.08))

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(vm.logs.enumerated()), id: \.offset) { _, log in
                                    Text(log)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(log.contains("❌") ? .red : (log.contains("✅") || log.contains("🟢") ? neonGreen : textMuted))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                        }
                    }
                    .frame(minWidth: 260, idealWidth: 310, maxWidth: 400)
                    .background(cardDark)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Footer Bar
            footerSection
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(red: 0.086, green: 0.090, blue: 0.106))
        }
        .background(bgDark)
        .sheet(isPresented: $vm.showingSettings) {
            VStack(spacing: 0) {
                HStack {
                    Text("USBAnywhere Server Settings")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") {
                        vm.showingSettings = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(neonGreen)
                    .cornerRadius(6)
                }
                .padding(14)
                .background(cardDark)

                SettingsView()
                    .environmentObject(vm)
            }
            .frame(width: 540, height: 480)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 16) {
            // App Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "cable.connector.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(neonGreen)
                    Text("USBAnywhere Server")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("macOS v3.2.0")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(neonCyan.opacity(0.15))
                        .foregroundColor(neonCyan)
                        .cornerRadius(4)
                }
                Text("Zero-Trust Native IOKit USB/IP Server & Dynamic Control Daemon")
                    .font(.system(size: 11))
                    .foregroundColor(textMuted)
            }

            Spacer()

            // IP Pill (Click to copy)
            Button(action: { vm.copyIpToClipboard() }) {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .font(.system(size: 11))
                        .foregroundColor(neonCyan)
                    Text("\(vm.primaryIpAddress):\(vm.serverPort)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundColor(textMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(cardDark)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(neonCyan.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Click to copy Server IP address")

            // Server Start / Stop Toggle
            Button(action: { vm.toggleServer() }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.isServerActive ? Color.black : Color.black)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(vm.isServerActive ? neonGreen : Color.red)
                                .frame(width: 8, height: 8)
                        )
                    Text(vm.isServerActive ? "SERVER ACTIVE" : "START SERVER")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(vm.isServerActive ? neonGreen : .black)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(vm.isServerActive ? Color(red: 0.10, green: 0.16, blue: 0.08) : neonGreen)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(vm.isServerActive ? neonGreen : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Settings Button
            Button(action: { vm.showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(textMuted)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .help("Preferences & Security")
        }
    }

    // MARK: - Toolbar
    private var toolbarSection: some View {
        HStack(spacing: 10) {
            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(textMuted)
                TextField("Search devices...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(cardDark)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.08), lineWidth: 1))

            Spacer()

            // Share All
            Button(action: { vm.shareAll() }) {
                Label("Share All", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(neonGreen)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Stop All
            Button(action: { vm.stopAll() }) {
                Label("Stop All", systemImage: "xmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Refresh
            Button(action: { vm.refreshDevices() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textMuted)
                    .padding(6)
                    .background(cardDark)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Refresh connected devices")
        }
    }

    // MARK: - Empty State
    private var emptyStateSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 40))
                .foregroundColor(textMuted.opacity(0.5))
            Text("No USB Peripherals Found")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text("Plug a flight stick, gamepad, webcam, or USB device into this Mac.\nDevices will appear here automatically.")
                .font(.system(size: 12))
                .foregroundColor(textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }

    // MARK: - Footer
    private var footerSection: some View {
        HStack {
            Text("\(vm.devices.count) USB Peripherals (\(vm.devices.filter { $0.isBound }.count) Shared, \(vm.activeClientsCount) Attached)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(textMuted)

            Spacer()

            HStack(spacing: 12) {
                Text("📌 \(vm.autoBindCount) Auto-Bound")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textMuted)

                Button(action: { showingLogs.toggle() }) {
                    Label(showingLogs ? "Hide Logs" : "Show Logs",
                          systemImage: "sidebar.right")
                        .font(.system(size: 11))
                        .foregroundColor(neonCyan)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Device Card Row Component
struct DeviceCardRow: View {
    @ObservedObject var device: USBDeviceInfo
    @EnvironmentObject var vm: ServerViewModel

    private let cardDark = Color(red: 0.075, green: 0.078, blue: 0.090)   // #131417 Unified Surface Elevated
    private let neonGreen = Color(red: 0.824, green: 0.973, blue: 0.0)    // #D2F800 Acid Lime Accent
    private let neonCyan = Color(red: 0.0, green: 0.898, blue: 1.0)       // #00E5FF Electric Cyan
    private let textMuted = Color(red: 0.631, green: 0.631, blue: 0.667)  // #A1A1AA Zinc-400

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Category Icon Pill
            VStack {
                Text(device.categoryEmoji)
                    .font(.system(size: 20))
            }
            .frame(width: 38, height: 38)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)

            // Device Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(device.cleanProductName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Category Pill
                    Text(device.category.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(neonCyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(neonCyan.opacity(0.14))
                        .cornerRadius(4)
                }

                Text("\(device.manufacturer ?? "Generic") • \(device.speedLabel)")
                    .font(.system(size: 11))
                    .foregroundColor(textMuted)
                    .lineLimit(1)

                // Metadata Badges Row
                HStack(spacing: 6) {
                    BadgePill(text: "BUS \(device.busId)", color: neonCyan)
                    BadgePill(text: "VID:\(device.vidPidString)", color: textMuted)

                    if device.isBound {
                        BadgePill(text: device.isClaimed ? "ATTACHED" : "SHARED", color: neonGreen)
                    }
                }
            }

            Spacer()

            // Auto-Bind Checkbox & Share Button
            HStack(spacing: 10) {
                Button(action: { vm.toggleAutoBind(device: device) }) {
                    Image(systemName: AutoBindManager.shared.isAutoBound(vidPid: device.vidPidString) ? "pin.fill" : "pin")
                        .font(.system(size: 12))
                        .foregroundColor(AutoBindManager.shared.isAutoBound(vidPid: device.vidPidString) ? neonCyan : textMuted.opacity(0.5))
                        .padding(6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Auto-Bind: Remember and automatically share when plugged in")

                Button(action: { vm.toggleShare(device: device) }) {
                    Text(device.isBound ? "Stop" : "Share")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(device.isBound ? .white : .black)
                        .frame(width: 60, height: 26)
                        .background(device.isBound ? Color(red: 0.25, green: 0.12, blue: 0.12) : neonGreen)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(device.isBound ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(cardDark)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(device.isBound ? neonGreen.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Badge Pill Component
struct BadgePill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(red: 0.043, green: 0.047, blue: 0.055))
            .cornerRadius(4)
    }
}
#endif
