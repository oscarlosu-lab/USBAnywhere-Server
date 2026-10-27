// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Copyright (c) 2025-2026 oscarlosu-lab
// Source: https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;
using USBAnywhere.Server.Models;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Industrial wrapper for usbipd.exe commands
/// </summary>
public class UsbipdService : IDisposable
{
    private string _usbipdPath = "usbipd.exe";
    private Dictionary<string, string> _wmiDeviceCache = new();
    private DateTime _lastWmiCacheUpdate = DateTime.MinValue;

    public event EventHandler<string>? LogMessage;
    public bool IsUsbipdAvailable { get; private set; }

    public UsbipdService()
    {
        Initialize();
    }

    private void Initialize()
    {
        var programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        var systemPath = Path.Combine(programFiles, "usbipd-win", "usbipd.exe");
        var bundledPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "drivers", "usbipd.exe");

        if (File.Exists(systemPath))
        {
            _usbipdPath = systemPath;
            IsUsbipdAvailable = true;
        }
        else if (CheckUsbipdInPath())
        {
            _usbipdPath = "usbipd.exe";
            IsUsbipdAvailable = true;
        }
        else if (File.Exists(bundledPath))
        {
            _usbipdPath = bundledPath;
            IsUsbipdAvailable = CheckExecutable(bundledPath);
        }
        else
        {
            _usbipdPath = "usbipd.exe";
            IsUsbipdAvailable = false;
        }
    }

    public void Reinitialize() => Initialize();

    private static bool CheckUsbipdInPath() => CheckExecutable("usbipd.exe");

    private static bool CheckExecutable(string fileName)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = "--version",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
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

    /// <summary>
    /// Get list of USB devices using usbipd list + WMI enrichment (Async)
    /// </summary>
    public async Task<List<LocalUsbDevice>> GetDevicesAsync()
    {
        var devices = new List<LocalUsbDevice>();
        if (!IsUsbipdAvailable) return devices;

        try
        {
            var output = await RunCommandAsync("list");
            if (string.IsNullOrEmpty(output)) return devices;

            await UpdateWmiCacheIfNeededAsync();

            var lines = output.Split('\n', StringSplitOptions.RemoveEmptyEntries);
            var dataStarted = false;

            foreach (var rawLine in lines)
            {
                var line = rawLine.Trim();
                if (string.IsNullOrWhiteSpace(line)) continue;

                // Stop parsing when entering Persisted (offline) section
                if (line.StartsWith("Persisted:", StringComparison.OrdinalIgnoreCase))
                {
                    break;
                }

                if (line.Contains("BUSID", StringComparison.OrdinalIgnoreCase) &&
                    line.Contains("STATE", StringComparison.OrdinalIgnoreCase))
                {
                    dataStarted = true;
                    continue;
                }

                if (!dataStarted) continue;

                // Match usbipd-win output including "Shared (forced)" and "Attached"
                var match = Regex.Match(
                    line,
                    @"^(\d+-[\d.]+)\s+([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\s+(.+?)\s{2,}(Not shared|Shared(?:\s*\(forced\))?|Attached.*)$",
                    RegexOptions.IgnoreCase);

                if (match.Success)
                {
                    var vid = int.Parse(match.Groups[2].Value, System.Globalization.NumberStyles.HexNumber);
                    var pid = int.Parse(match.Groups[3].Value, System.Globalization.NumberStyles.HexNumber);
                    var baseName = match.Groups[4].Value.Trim();
                    var rawState = match.Groups[5].Value.Trim();

                    var vidPidKey = $"{vid:X4}:{pid:X4}";
                    string enrichedName = baseName;
                    if (_wmiDeviceCache.TryGetValue(vidPidKey, out var wmiName))
                    {
                        enrichedName = wmiName;
                    }

                    bool isNotShared = rawState.StartsWith("Not shared", StringComparison.OrdinalIgnoreCase);
                    bool isExported = !isNotShared; // Both "Shared", "Shared (forced)", and "Attached" can be stopped/unbound

                    var device = new LocalUsbDevice
                    {
                        BusId = match.Groups[1].Value,
                        VendorId = vid,
                        ProductId = pid,
                        Name = enrichedName,
                        Description = baseName,
                        Status = rawState,
                        IsExported = isExported,
                        IsNotShared = isNotShared
                    };

                    devices.Add(device);
                }
            }
        }
        catch (Exception ex)
        {
            Log($"⚠️ Error: {ex.Message}");
        }

        return devices;
    }

    private async Task UpdateWmiCacheIfNeededAsync()
    {
        var cacheSeconds = Math.Clamp(SettingsService.Current.WmiCacheDurationSeconds, 5, 300);
        if (DateTime.Now - _lastWmiCacheUpdate < TimeSpan.FromSeconds(cacheSeconds) && _wmiDeviceCache.Count > 0)
        {
            return;
        }

        await Task.Run(() =>
        {
            try
            {
                var newCache = new Dictionary<string, string>();
                using var searcher = new System.Management.ManagementObjectSearcher(
                    "SELECT DeviceID, Name, Caption FROM Win32_PnPEntity WHERE DeviceID LIKE 'USB%'");

                foreach (var obj in searcher.Get())
                {
                    var deviceId = obj["DeviceID"]?.ToString() ?? "";
                    var name = obj["Name"]?.ToString() ?? obj["Caption"]?.ToString() ?? "";

                    var vidMatch = Regex.Match(deviceId, @"VID_([0-9A-Fa-f]{4})");
                    var pidMatch = Regex.Match(deviceId, @"PID_([0-9A-Fa-f]{4})");

                    if (vidMatch.Success && pidMatch.Success && !string.IsNullOrWhiteSpace(name))
                    {
                        var key = $"{vidMatch.Groups[1].Value.ToUpperInvariant()}:{pidMatch.Groups[1].Value.ToUpperInvariant()}";
                        if (!newCache.ContainsKey(key) || name.Length > newCache[key].Length)
                        {
                            newCache[key] = name;
                        }
                    }
                }

                _wmiDeviceCache = newCache;
                _lastWmiCacheUpdate = DateTime.Now;
            }
            catch { }
        });
    }

    /// <summary>
    /// Share a device (bind)
    /// </summary>
    public async Task<bool> BindDeviceAsync(string busId)
    {
        if (!SecurityHelper.IsValidBusId(busId))
        {
            Log($"❌ Invalid Bus ID format: {busId}");
            return false;
        }

        var sanitizedBusId = SecurityHelper.SanitizeArgument(busId);
        Log($"📤 Sharing device {sanitizedBusId}...");

        bool result = await RunAdminCommandAsync($"bind --busid={sanitizedBusId} --force");

        if (result)
        {
            Log($"✅ Device {sanitizedBusId} is now shared");
        }
        return result;
    }

    /// <summary>
    /// Stop sharing a device (unbind)
    /// </summary>
    public async Task<bool> UnbindDeviceAsync(string busId)
    {
        if (!SecurityHelper.IsValidBusId(busId))
        {
            Log($"❌ Invalid Bus ID format: {busId}");
            return false;
        }

        var sanitizedBusId = SecurityHelper.SanitizeArgument(busId);
        Log($"🚫 Stopping share for {sanitizedBusId}...");

        bool result = await RunAdminCommandAsync($"unbind --busid={sanitizedBusId}");

        if (result)
        {
            Log($"✅ Device {sanitizedBusId} is no longer shared");
        }
        return result;
    }

    private async Task<string> RunCommandAsync(string args)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = _usbipdPath,
                Arguments = args,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = psi };
            process.Start();

            var outputTask = process.StandardOutput.ReadToEndAsync();
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            try
            {
                await process.WaitForExitAsync(cts.Token);
            }
            catch (OperationCanceledException)
            {
                try { process.Kill(entireProcessTree: true); } catch { }
                return "";
            }

            return await outputTask;
        }
        catch
        {
            return "";
        }
    }

    private async Task<bool> RunAdminCommandAsync(string args)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = _usbipdPath,
                Arguments = args,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = psi };
            process.Start();

            var errTask = process.StandardError.ReadToEndAsync();
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(15));
            await process.WaitForExitAsync(cts.Token);

            if (process.ExitCode != 0)
            {
                var err = (await errTask).Trim();
                if (!string.IsNullOrEmpty(err))
                {
                    Log($"⚠️ usbipd: {err}");
                }
                return false;
            }

            return true;
        }
        catch (Exception ex)
        {
            Log($"❌ Error: {ex.Message}");
            return false;
        }
    }

    private void Log(string message) =>
        LogMessage?.Invoke(this, message);

    public void Dispose() { }
}
