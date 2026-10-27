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
                <string>--auto-bind</string>
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
            print("❌ Root privileges required. Please run with 'sudo'.")
            return false
        }
        
        let content = generatePlistContent()
        do {
            try content.write(toFile: plistPath, atomically: true, encoding: .utf8)
            
            // Set permissions (chown root:wheel & chmod 644)
            _ = runCommand("chown", args: ["root:wheel", plistPath])
            _ = runCommand("chmod", args: ["644", plistPath])
            
            // Load service
            _ = runCommand("launchctl", args: ["unload", plistPath])
            let result = runCommand("launchctl", args: ["load", "-w", plistPath])
            
            if result.exitCode == 0 {
                print("✅ USBAnywhere Server service installed and started successfully.")
                print("   Daemon: \(plistPath)")
                print("   Logs:   \(logPath)")
                return true
            } else {
                print("⚠️ launchctl returned non-zero exit code: \(result.exitCode)")
                return false
            }
        } catch {
            print("❌ Failed to write plist: \(error.localizedDescription)")
            return false
        }
    }
    
    public static func uninstall() -> Bool {
        guard geteuid() == 0 else {
            print("❌ Root privileges required. Please run with 'sudo'.")
            return false
        }
        
        _ = runCommand("launchctl", args: ["unload", "-w", plistPath])
        if FileManager.default.fileExists(atPath: plistPath) {
            try? FileManager.default.removeItem(atPath: plistPath)
        }
        print("✅ USBAnywhere Server service removed.")
        return true
    }
    
    @discardableResult
    private static func runCommand(_ executable: String, args: [String]) -> (output: String, exitCode: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        let which = Process()
        let pipe = Pipe()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/\(executable)")
        if !FileManager.default.fileExists(atPath: "/usr/bin/\(executable)") {
            which.executableURL = URL(fileURLWithPath: "/bin/\(executable)")
        }
        which.arguments = args
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
