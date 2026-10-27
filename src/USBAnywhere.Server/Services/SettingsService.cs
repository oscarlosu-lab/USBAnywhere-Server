// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Settings Service
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

using System.IO;
using System.Text.Json;
using USBAnywhere.Server.Models;

namespace USBAnywhere.Server.Services;

public static class SettingsService
{
    private static AppSettings? _current;
    private static readonly object _lock = new();

    public static AppSettings Current
    {
        get
        {
            if (_current == null)
            {
                lock (_lock)
                {
                    _current ??= Load();
                }
            }
            return _current;
        }
    }

    private static string GetSettingsPath() => PathService.SettingsFilePath;

    public static AppSettings Load()
    {
        lock (_lock)
        {
            try
            {
                var path = GetSettingsPath();
                if (File.Exists(path))
                {
                    var json = File.ReadAllText(path);
                    var settings = JsonSerializer.Deserialize<AppSettings>(json);
                    if (settings != null)
                    {
                        LogService.Info($"Settings loaded from: {path}");
                        return settings;
                    }
                }
            }
            catch (Exception ex)
            {
                LogService.Error($"Failed to load settings: {ex.Message}");
            }

            LogService.Info("Using default settings");
            return new AppSettings();
        }
    }

    public static bool Save()
    {
        lock (_lock)
        {
            try
            {
                var path = GetSettingsPath();
                var dir = Path.GetDirectoryName(path);
                if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                {
                    Directory.CreateDirectory(dir);
                }

                var options = new JsonSerializerOptions { WriteIndented = true };
                var json = JsonSerializer.Serialize(Current, options);
                var tempPath = path + ".tmp";
                File.WriteAllText(tempPath, json);
                File.Move(tempPath, path, overwrite: true);

                LogService.Info($"Settings saved atomically to: {path}");
                return true;
            }
            catch (Exception ex)
            {
                LogService.Error($"Failed to save settings: {ex.Message}");
                return false;
            }
        }
    }

    public static void Reset()
    {
        lock (_lock)
        {
            _current = new AppSettings();
        }
        Save();
        LogService.Info("Settings reset to defaults");
    }

    public static bool Export(string filePath)
    {
        try
        {
            var options = new JsonSerializerOptions { WriteIndented = true };
            var json = JsonSerializer.Serialize(Current, options);
            File.WriteAllText(filePath, json);
            LogService.Info($"Settings exported to: {filePath}");
            return true;
        }
        catch (Exception ex)
        {
            LogService.Error($"Failed to export settings: {ex.Message}");
            return false;
        }
    }

    public static bool Import(string filePath)
    {
        try
        {
            if (!File.Exists(filePath))
            {
                LogService.Error($"Import file not found: {filePath}");
                return false;
            }

            var json = File.ReadAllText(filePath);
            var settings = JsonSerializer.Deserialize<AppSettings>(json);

            if (settings != null)
            {
                lock (_lock)
                {
                    _current = settings;
                }
                Save();
                LogService.Info($"Settings imported from: {filePath}");
                return true;
            }
        }
        catch (Exception ex)
        {
            LogService.Error($"Failed to import settings: {ex.Message}");
        }
        return false;
    }
}
