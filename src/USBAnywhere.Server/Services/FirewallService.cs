// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Firewall Configuration Service
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Service for managing Windows Firewall rules for USB/IP
/// </summary>
public static class FirewallService
{
    private const string RuleName = "USBAnywhere Server (TCP 3240)";
    private const string RuleNameUdp = "USBAnywhere Discovery (UDP 3241)";
    private const string LegacyRuleName = "SnakeUSBIP Server (TCP 3240)";
    private const int Port = 3240;
    private const int DiscoveryPort = 3241;
    private const int TlsPort = 3243;
    private static readonly string NetshPath = Path.Combine(Environment.SystemDirectory, "netsh.exe");

    public static string BuildTcpRuleArguments(string ruleName, string remoteIpClause, string? bindAddress = null, bool includeTlsPort = true)
    {
        var ports = includeTlsPort ? $"{Port},{DiscoveryPort},{TlsPort}" : $"{Port},{DiscoveryPort}";
        var localIpClause = "";
        if (!string.IsNullOrWhiteSpace(bindAddress) &&
            SecurityHelper.IsValidBindAddress(bindAddress) &&
            !string.Equals(bindAddress.Trim(), "0.0.0.0", StringComparison.Ordinal) &&
            !string.Equals(bindAddress.Trim(), "::", StringComparison.Ordinal))
        {
            localIpClause = $" localip={bindAddress.Trim()}";
        }
        return $"advfirewall firewall add rule name=\"{ruleName}\" dir=in action=allow protocol=tcp localport={ports}{localIpClause} profile=private,domain {remoteIpClause}";
    }

    public static string BuildUdpRuleArguments(string ruleName, string remoteIpClause, string? bindAddress = null)
    {
        var localIpClause = "";
        if (!string.IsNullOrWhiteSpace(bindAddress) &&
            SecurityHelper.IsValidBindAddress(bindAddress) &&
            !string.Equals(bindAddress.Trim(), "0.0.0.0", StringComparison.Ordinal) &&
            !string.Equals(bindAddress.Trim(), "::", StringComparison.Ordinal))
        {
            localIpClause = $" localip={bindAddress.Trim()}";
        }
        return $"advfirewall firewall add rule name=\"{ruleName}\" dir=in action=allow protocol=udp localport={DiscoveryPort}{localIpClause} profile=private,domain {remoteIpClause}";
    }

    public static bool IsRuleConfigured()
    {
        if (CheckRule(RuleName)) return true;
        return !string.Equals(LegacyRuleName, RuleName, StringComparison.OrdinalIgnoreCase) && CheckRule(LegacyRuleName);
    }

    private static bool CheckRule(string ruleName)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = NetshPath,
                Arguments = $"advfirewall firewall show rule name=\"{ruleName}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process == null) return false;

            var outputTask = process.StandardOutput.ReadToEndAsync();
            if (!process.WaitForExit(5000))
            {
                try { process.Kill(entireProcessTree: true); } catch { }
                return false;
            }

            if (process.ExitCode != 0) return false;
            var output = outputTask.GetAwaiter().GetResult();
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
                var validIps = allowedIps
                    .Split(',', StringSplitOptions.RemoveEmptyEntries)
                    .Select(ip => ip.Trim())
                    .Where(ip => Regex.IsMatch(ip, @"^[0-9a-fA-F:./]+$"))
                    .ToList();
                remoteIpClause = validIps.Count > 0
                    ? $"remoteip=\"{string.Join(",", validIps)}\""
                    : "remoteip=127.0.0.1";
            }
            else if (SettingsService.Current.WhitelistEnabled)
            {
                var validIps = SettingsService.Current.WhitelistedIPs
                    .Where(ip => !string.IsNullOrWhiteSpace(ip) && Regex.IsMatch(ip.Trim(), @"^[0-9a-fA-F:./]+$"))
                    .Select(ip => ip.Trim())
                    .ToList();
                remoteIpClause = validIps.Count > 0
                    ? $"remoteip=\"{string.Join(",", validIps)}\""
                    : "remoteip=127.0.0.1";
            }
            else
            {
                remoteIpClause = "remoteip=localsubnet,100.64.0.0/10,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16";
            }

            var bindAddr = SettingsService.Current.BindAddress;
            var inboundResult = await RunNetshCommandAsync(BuildTcpRuleArguments(RuleName, remoteIpClause, bindAddr, includeTlsPort: true));
            await RunNetshCommandAsync(BuildUdpRuleArguments(RuleNameUdp, remoteIpClause, bindAddr));

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
            var r2 = !string.Equals(LegacyRuleName, RuleName, StringComparison.OrdinalIgnoreCase)
                && await RunNetshCommandAsync($"advfirewall firewall delete rule name=\"{LegacyRuleName}\"");
            var r3 = await RunNetshCommandAsync($"advfirewall firewall delete rule name=\"{RuleNameUdp}\"");
            var result = r1 || r2 || r3;

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
                FileName = NetshPath,
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
