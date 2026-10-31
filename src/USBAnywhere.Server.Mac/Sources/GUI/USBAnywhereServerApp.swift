// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - SwiftUI App Lifecycle
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

#if canImport(SwiftUI)
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@available(macOS 13.0, *)
public struct USBAnywhereServerApp: App {
    @StateObject private var viewModel = ServerViewModel()
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some Scene {
        // Main Dashboard Window
        Window("USBAnywhere Server", id: "dashboard") {
            ServerDashboardView()
                .environmentObject(viewModel)
                .frame(minWidth: 850, minHeight: 550)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 950, height: 600)

        // Menu Bar Extra Item
        MenuBarExtra("USBAnywhere", systemImage: "cable.connector") {
            MenuBarView(
                onOpenDashboard: {
                    #if os(macOS)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "dashboard")
                    #endif
                },
                onOpenSettings: {
                    #if os(macOS)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "dashboard")
                    #endif
                }
            )
            .environmentObject(viewModel)
        }
        .menuBarExtraStyle(.window)

        // Settings / Preferences Window
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .frame(width: 500, height: 420)
        }
    }
}
#endif
