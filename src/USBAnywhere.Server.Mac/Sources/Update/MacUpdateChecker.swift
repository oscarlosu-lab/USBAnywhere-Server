// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - GitHub Releases & SHA256SUMS Updater
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum MacUpdateChecker {
    public static let releasesApiUrl = "https://api.github.com/repos/oscarlosu-lab/USBAnywhere-Server/releases/latest"

    public static func isNewerVersion(latest: String, current: String) -> Bool {
        let parse: (String) -> [Int] = { v in
            v.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                .split(separator: "-")
                .first?
                .split(separator: ".")
                .compactMap { Int($0) } ?? []
        }
        let a = parse(latest)
        let b = parse(current)
        let count = max(a.count, b.count)
        for i in 0..<count {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }

    public static func parseSha256Sums(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(whereSeparator: \.isWhitespace)
            if parts.count >= 2 {
                let hash = String(parts[0]).lowercased()
                let file = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                if hash.count == 64 {
                    result[file] = hash
                }
            }
        }
        return result
    }

    public static func verifySha256(data: Data, expectedHex: String) -> Bool {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return hex == expectedHex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        #else
        return false
        #endif
    }
}
