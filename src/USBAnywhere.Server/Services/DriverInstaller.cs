/*
 * USBAnywhere Server - Driver Installation Module
 * Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
 * GPL v3 License
 */

using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using Microsoft.Win32;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Handles automatic installation of usbipd-win if not present
/// </summary>
public class DriverInstaller
{
    public event EventHandler<string>? LogMessage;

    public bool IsUsbipdInstalled()
    {
        using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\usbipd-win");
        if (key != null) return true;

        var programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var usbipdPath = Path.Combine(programFiles, "usbipd-win", "usbipd.exe");
        if (File.Exists(usbipdPath)) return true;

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "usbipd.exe",
                Arguments = "--version",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                CreateNoWindow = true
            };
            using var process = Process.Start(psi);
            if (process != null)
            {
                process.WaitForExit(3000);
                return process.ExitCode == 0;
            }
        }
        catch { }

        return false;
    }

    public bool IsRunningAsAdmin()
    {
        using var identity = WindowsIdentity.GetCurrent();
        var principal = new WindowsPrincipal(identity);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

    public async Task<bool> InstallUsbipdAsync()
    {
        var msiPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "drivers", "usbipd-win.msi");

        if (!File.Exists(msiPath))
        {
            Log("❌ MSI installer not found in drivers folder");
            return false;
        }

        if (!IsRunningAsAdmin())
        {
            Log("⚠️ Administrator privileges required for installation");
            return await RestartAsAdminForInstall();
        }

        Log("📦 Installing usbipd-win driver...");

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "msiexec.exe",
                Arguments = $"/i \"{msiPath}\" /quiet /norestart",
                UseShellExecute = !IsRunningAsAdmin(),
                Verb = IsRunningAsAdmin() ? "" : "runas",
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process == null) return false;

            await process.WaitForExitAsync();

            if (process.ExitCode == 0 || process.ExitCode == 3010)
            {
                Log("✅ usbipd-win installed successfully!");
                return true;
            }
            else
            {
                Log($"❌ Installation failed with exit code: {process.ExitCode}");
                return false;
            }
        }
        catch (Exception ex)
        {
            Log($"❌ Installation error: {ex.Message}");
            return false;
        }
    }

    private Task<bool> RestartAsAdminForInstall()
    {
        try
        {
            var exePath = Environment.ProcessPath;
            if (string.IsNullOrEmpty(exePath)) return Task.FromResult(false);

            var psi = new ProcessStartInfo
            {
                FileName = exePath,
                Arguments = "--install-driver",
                UseShellExecute = true,
                Verb = "runas"
            };

            Process.Start(psi);
            Environment.Exit(0);
            return Task.FromResult(true);
        }
        catch
        {
            Log("❌ Failed to restart as administrator");
            return Task.FromResult(false);
        }
    }

    private void Log(string message) =>
        LogMessage?.Invoke(this, message);

    public async Task<bool> UninstallUsbipdAsync()
    {
        Log("🗑️ Uninstalling usbipd-win...");

        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "winget",
                Arguments = "uninstall --id dorssel.usbipd-win --silent --disable-interactivity --accept-source-agreements",
                UseShellExecute = !IsRunningAsAdmin(),
                Verb = IsRunningAsAdmin() ? "" : "runas",
                CreateNoWindow = true,
                RedirectStandardOutput = IsRunningAsAdmin(),
                RedirectStandardError = IsRunningAsAdmin()
            };

            using var process = Process.Start(psi);
            if (process == null)
            {
                return await UninstallViaMsiexec();
            }

            await process.WaitForExitAsync();

            if (process.ExitCode == 0)
            {
                Log("✅ usbipd-win uninstalled successfully");
                return true;
            }
            else
            {
                return await UninstallViaMsiexec();
            }
        }
        catch
        {
            return await UninstallViaMsiexec();
        }
    }

    private async Task<bool> UninstallViaMsiexec()
    {
        try
        {
            string? productCode = FindMsiProductCode();
            if (string.IsNullOrEmpty(productCode))
            {
                Log("⚠️ usbipd-win MSI product code not found in registry.");
                return false;
            }

            Log($"📦 Uninstalling via msiexec for {productCode}...");
            var psi = new ProcessStartInfo
            {
                FileName = "msiexec.exe",
                Arguments = $"/x {productCode} /quiet /norestart",
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = Process.Start(psi);
            if (process == null) return false;

            await process.WaitForExitAsync();
            if (process.ExitCode == 0 || process.ExitCode == 3010)
            {
                Log("✅ usbipd-win uninstalled via MSI.");
                return true;
            }

            Log($"❌ msiexec uninstall exited with code: {process.ExitCode}");
            return false;
        }
        catch (Exception ex)
        {
            Log($"❌ Uninstall failed: {ex.Message}");
            return false;
        }
    }

    private static string? FindMsiProductCode()
    {
        string[] subkeys = {
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        };

        foreach (var subkey in subkeys)
        {
            using var root = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(subkey);
            if (root == null) continue;

            foreach (var subName in root.GetSubKeyNames())
            {
                using var appKey = root.OpenSubKey(subName);
                if (appKey == null) continue;

                var displayName = appKey.GetValue("DisplayName")?.ToString() ?? "";
                if (displayName.Contains("usbipd-win", StringComparison.OrdinalIgnoreCase))
                {
                    if (subName.StartsWith("{") && subName.EndsWith("}"))
                    {
                        return subName;
                    }

                    var uninstallStr = appKey.GetValue("UninstallString")?.ToString() ?? "";
                    var match = System.Text.RegularExpressions.Regex.Match(uninstallStr, @"\{[0-9a-fA-F\-]+\}");
                    if (match.Success) return match.Value;
                }
            }
        }
        return null;
    }
}
