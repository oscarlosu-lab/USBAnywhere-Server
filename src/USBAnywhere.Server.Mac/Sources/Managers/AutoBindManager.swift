// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Persistent Auto-Bind Manager
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

public final class AutoBindManager {
    public static let shared = AutoBindManager()
    private let userDefaultsKey = "USBAnywhere.AutoBoundVidPids"
    private var rememberedVidPids: Set<String> = []

    private init() {
        load()
    }

    public func isAutoBound(vidPid: String) -> Bool {
        return rememberedVidPids.contains(vidPid.uppercased())
    }

    public func toggleAutoBind(vidPid: String) -> Bool {
        let key = vidPid.uppercased()
        if rememberedVidPids.contains(key) {
            rememberedVidPids.remove(key)
        } else {
            rememberedVidPids.insert(key)
        }
        save()
        return rememberedVidPids.contains(key)
    }

    public func getAutoBoundList() -> Set<String> {
        return rememberedVidPids
    }

    public func clearAll() {
        rememberedVidPids.removeAll()
        save()
    }

    private func load() {
        if let array = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            rememberedVidPids = Set(array.map { $0.uppercased() })
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(rememberedVidPids), forKey: userDefaultsKey)
    }
}
