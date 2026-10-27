// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Application Settings Model
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

namespace USBAnywhere.Server.Models;

/// <summary>
/// Application settings model - persisted as JSON
/// </summary>
public class AppSettings
{
    public bool StartWithWindows { get; set; } = false;
    public bool StartMinimized { get; set; } = false;
    public bool ShowNotifications { get; set; } = true;
    public bool CheckForUpdates { get; set; } = true;
    public string Theme { get; set; } = "dark";
    public string Language { get; set; } = "";

    // AUTO-BIND
    public bool AutoBindEnabled { get; set; } = false;
    public List<string> AutoBindDevices { get; set; } = new();

    // SECURITY
    public bool WhitelistEnabled { get; set; } = false;
    public List<string> WhitelistedIPs { get; set; } = new();
    public bool RequirePIN { get; set; } = false;
    public string PIN { get; set; } = "";

    // NETWORK
    public bool FirewallConfigured { get; set; } = false;

    // ADVANCED
    public int RefreshIntervalSeconds { get; set; } = 3;
    public int WmiCacheDurationSeconds { get; set; } = 30;
    public string WebhookUrl { get; set; } = "";
}
