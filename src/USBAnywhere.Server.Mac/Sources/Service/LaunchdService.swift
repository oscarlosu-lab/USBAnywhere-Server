// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server for macOS - Launchd Background Daemon Service Manager
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

import Foundation

public enum LaunchdService {
    public static let plistPath = "/Library/LaunchDaemons/com.usbanywhere.server.plist"
    public static let binaryPath = "/usr/local/bin/usbanywhere-server-mac"
    public static let logPath = "/var/log/usbanywhere-server.log"
    
    public static func generatePlistContent() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.usbanywhere.server</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
                <string>serve</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(logPath)</string>
            <key>StandardErrorPath</key>
            <string>\(logPath)</string>
        </dict>
        </plist>
        """
    }
    
    public static func install() -> Bool {
        guard geteuid() == 0 else {
            print("❌ Error: Installing the background service requires root privileges.")
            print("💡 Run: sudo usbanywhere-server-mac install-service")
            return false
        }
        
        let currentExec = CommandLine.arguments[0]
        if currentExec != binaryPath && FileManager.default.fileExists(atPath: currentExec) {
            do {
                if FileManager.default.fileExists(atPath: binaryPath) {
                    try FileManager.default.removeItem(atPath: binaryPath)
                }
                try FileManager.default.copyItem(atPath: currentExec, toPath: binaryPath)
                _ = runCommand("/bin/chmod", args: ["755", binaryPath])
                print("📦 Installed binary to \(binaryPath)")
            } catch {
                print("⚠️ Warning: Could not copy binary to \(binaryPath): \(error.localizedDescription)")
            }
        }
        
        do {
            let content = generatePlistContent()
            try content.write(toFile: plistPath, atomically: true, encoding: .utf8)
            _ = runCommand("/usr/sbin/chown", args: ["root:wheel", plistPath])
            _ = runCommand("/bin/chmod", args: ["644", plistPath])
            
            _ = runCommand("/bin/launchctl", args: ["unload", plistPath])
            let loadRes = runCommand("/bin/launchctl", args: ["load", "-w", plistPath])
            if loadRes.exitCode == 0 {
                print("✅ Launchd service installed and started (\(plistPath))")
                print("📄 Logs available at: \(logPath)")
                return true
            } else {
                print("⚠️ launchctl load returned exit code \(loadRes.exitCode): \(loadRes.output)")
                return false
            }
        } catch {
            print("❌ Failed to write plist to \(plistPath): \(error.localizedDescription)")
            return false
        }
    }
    
    public static func uninstall() -> Bool {
        guard geteuid() == 0 else {
            print("❌ Error: Uninstalling the background service requires root privileges.")
            print("💡 Run: sudo usbanywhere-server-mac uninstall-service")
            return false
        }
        
        if FileManager.default.fileExists(atPath: plistPath) {
            _ = runCommand("/bin/launchctl", args: ["unload", plistPath])
            do {
                try FileManager.default.removeItem(atPath: plistPath)
                print("✅ Launchd service removed (\(plistPath))")
                return true
            } catch {
                print("❌ Failed to remove \(plistPath): \(error.localizedDescription)")
                return false
            }
        } else {
            print("ℹ️ Service is not currently installed at \(plistPath).")
            return true
        }
    }
    
    private static func runCommand(_ executable: String, args: [String]) -> (output: String, exitCode: Int32) {
        let which = Process()
        which.executableURL = URL(fileURLWithPath: executable)
        which.arguments = args
        
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = pipe
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, which.terminationStatus)
        } catch {
            return (error.localizedDescription, 1)
        }
    }
}
