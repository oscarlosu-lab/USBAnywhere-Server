// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Firewall Configuration Service
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

using System.Diagnostics;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Service for managing Windows Firewall rules for USB/IP
/// </summary>
public static class FirewallService
{
    private const string RuleName = "USBAnywhere Server (TCP 3240)";
    private const string LegacyRuleName = "SnakeUSBIP Server (TCP 3240)";
    private const int Port = 3240;

    public static bool IsRuleConfigured()
    {
        return CheckRule(RuleName) || CheckRule(LegacyRuleName);
    }

    private static bool CheckRule(string ruleName)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "netsh",
                Arguments = $"advfirewall firewall show rule name=\"{ruleName}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process == null) return false;

            var output = process.StandardOutput.ReadToEnd();
            process.WaitForExit(5000);

            return output.Contains(ruleName, StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    public static async Task<bool> CreateRuleAsync(string? allowedIps = null)
    {
        try
        {
            LogService.Info("Creating hardened firewall rule for USB/IP...");

            // Remove previous rule first to avoid duplicates or loose policies
            await RemoveRuleAsync();

            string remoteIpClause;
            if (!string.IsNullOrWhiteSpace(allowedIps))
            {
                remoteIpClause = $"remoteip=\"{allowedIps}\"";
            }
            else if (SettingsService.Current.WhitelistEnabled && SettingsService.Current.WhitelistedIPs.Any())
            {
                remoteIpClause = $"remoteip=\"{string.Join(",", SettingsService.Current.WhitelistedIPs)}\"";
            }
            else
            {
                remoteIpClause = "remoteip=localsubnet";
            }

            var inboundResult = await RunNetshCommandAsync(
                $"advfirewall firewall add rule name=\"{RuleName}\" dir=in action=allow protocol=tcp localport={Port} profile=private,domain {remoteIpClause}");

            if (!inboundResult)
            {
                LogService.Error("Failed to create inbound firewall rule");
                return false;
            }

            LogService.Info($"✅ Firewall rule created: {RuleName} (profile=private,domain, {remoteIpClause})");
            SettingsService.Current.FirewallConfigured = true;
            SettingsService.Save();

            return true;
        }
        catch (Exception ex)
        {
            LogService.Error($"Failed to create firewall rule: {ex.Message}");
            return false;
        }
    }

    public static async Task<bool> RemoveRuleAsync()
    {
        try
        {
            LogService.Info("Removing firewall rule...");

            var r1 = await RunNetshCommandAsync($"advfirewall firewall delete rule name=\"{RuleName}\"");
            var r2 = await RunNetshCommandAsync($"advfirewall firewall delete rule name=\"{LegacyRuleName}\"");
            var result = r1 || r2;

            if (result)
            {
                LogService.Info("✅ Firewall rule removed");
                SettingsService.Current.FirewallConfigured = false;
                SettingsService.Save();
            }

            return result;
        }
        catch (Exception ex)
        {
            LogService.Error($"Failed to remove firewall rule: {ex.Message}");
            return false;
        }
    }

    private static async Task<bool> RunNetshCommandAsync(string arguments)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "netsh",
                Arguments = arguments,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = psi };
            process.Start();
            await process.WaitForExitAsync();

            return process.ExitCode == 0;
        }
        catch
        {
            return false;
        }
    }
}
