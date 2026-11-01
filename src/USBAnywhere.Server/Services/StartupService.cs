// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Windows Startup Service
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

using System.Diagnostics;
using System.IO;
using Microsoft.Win32;

namespace USBAnywhere.Server.Services;

public static class StartupService
{
    private const string TaskName = "USBAnywhere Server";
    private const string LegacyTaskName = "SnakeUSBIP Server";
    private const string AppName = "USBAnywhere Server";
    private const string LegacyAppName = "SnakeUSBIP Server";
    private const string RegistryKey = @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run";
    private static readonly string SchtasksPath = Path.Combine(Environment.SystemDirectory, "schtasks.exe");

    public static bool IsRegistered()
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = SchtasksPath,
                Arguments = $"/query /tn \"{TaskName}\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            using var proc = Process.Start(psi);
            if (proc != null)
            {
                proc.WaitForExit(5000);
                if (proc.ExitCode == 0) return true;
            }

            using var key = Registry.CurrentUser.OpenSubKey(RegistryKey, false);
            return key?.GetValue(AppName) != null;
        }
        catch
        {
            return false;
        }
    }

    public static bool Register()
    {
        try
        {
            var exePath = Environment.ProcessPath ?? Process.GetCurrentProcess().MainModule?.FileName;
            if (string.IsNullOrEmpty(exePath))
            {
                LogService.Error("Could not determine executable path for startup");
                return false;
            }

            var psi = new ProcessStartInfo
            {
                FileName = SchtasksPath,
                Arguments = $"/create /tn \"{TaskName}\" /tr \"\\\"{exePath}\\\" --minimized\" /sc onlogon /rl highest /f",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            bool scheduledTaskCreated = false;
            using (var proc = Process.Start(psi))
            {
                if (proc != null)
                {
                    proc.WaitForExit(5000);
                    scheduledTaskCreated = proc.ExitCode == 0;
                }
            }

            using var key = Registry.CurrentUser.OpenSubKey(RegistryKey, true);
            key?.DeleteValue(LegacyAppName, false);
            if (scheduledTaskCreated)
            {
                // Avoid duplicate launch: remove HKCU Run entry when elevated scheduled task succeeds
                key?.DeleteValue(AppName, false);
            }
            else
            {
                // Fallback to HKCU Run only if schtasks failed (e.g. non-admin)
                key?.SetValue(AppName, $"\"{exePath}\" --minimized");
            }

            SettingsService.Current.StartWithWindows = true;
            SettingsService.Save();

            LogService.Info($"✅ Registered for Windows startup: {exePath}");
            return true;
        }
        catch (Exception ex)
        {
            LogService.Error($"Failed to register for startup: {ex.Message}");
            return false;
        }
    }

    public static bool Unregister()
    {
        try
        {
            foreach (var tn in new[] { TaskName, LegacyTaskName })
            {
                var psi = new ProcessStartInfo
                {
                    FileName = SchtasksPath,
                    Arguments = $"/delete /tn \"{tn}\" /f",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                using var proc = Process.Start(psi);
                proc?.WaitForExit(5000);
            }

            using var key = Registry.CurrentUser.OpenSubKey(RegistryKey, true);
            key?.DeleteValue(AppName, false);
            key?.DeleteValue(LegacyAppName, false);

            SettingsService.Current.StartWithWindows = false;
            SettingsService.Save();

            LogService.Info("✅ Unregistered from Windows startup");
            return true;
        }
        catch (Exception ex)
        {
            LogService.Error($"Failed to unregister from startup: {ex.Message}");
            return false;
        }
    }

    public static void SyncWithSettings()
    {
        bool shouldBeRegistered = SettingsService.Current.StartWithWindows;
        bool isCurrentlyRegistered = IsRegistered();

        if (shouldBeRegistered && !isCurrentlyRegistered)
        {
            Register();
        }
        else if (!shouldBeRegistered && isCurrentlyRegistered)
        {
            Unregister();
        }
    }
}
