/*
 * USBAnywhere Server - Path Management Service
 * Copyright (c) 2025-2026 oscarlosu-lab
 * https://github.com/oscarlosu-lab/USBAnywhere-Server
 */

using System.IO;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Centralized service for managing file paths with strict Portable/Installable separation.
/// Portable Mode: Stores data in application directory (USB-ready).
/// Installed Mode: Stores data in %AppData%\USBAnywhere-Server (clean uninstall).
/// </summary>
public static class PathService
{
    private static readonly string _baseDir;
    private static readonly bool _isPortable;
    private static readonly bool _hasWriteAccess;

    public static bool IsPortable => _isPortable;
    public static bool HasWriteAccess => _hasWriteAccess;
    public static string BaseDirectory => _baseDir;
    public static string LogPath => GetPath("logs");
    public static string ThemePath => GetPath("themes");
    public static string DataPath => GetPath("data");
    public static string ConfigPath => DataPath;
    public static string SettingsFilePath => Path.Combine(DataPath, "settings.json");

    static PathService()
    {
        _baseDir = AppDomain.CurrentDomain.BaseDirectory;
        _hasWriteAccess = CheckWriteAccess(_baseDir);

        bool markerExists = File.Exists(Path.Combine(_baseDir, ".portable")) ||
                            File.Exists(Path.Combine(_baseDir, "portable.flag"));

        string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        bool inProgramFiles = (!string.IsNullOrEmpty(programFiles) && _baseDir.StartsWith(programFiles, StringComparison.OrdinalIgnoreCase)) ||
                              (!string.IsNullOrEmpty(programFilesX86) && _baseDir.StartsWith(programFilesX86, StringComparison.OrdinalIgnoreCase));

        // Even when running as Administrator (where Program Files is writable),
        // an installed copy in Program Files without a .portable marker must use %AppData%.
        _isPortable = _hasWriteAccess && (markerExists || !inProgramFiles);
    }

    private static string GetPath(string subFolder)
    {
        string root;
        if (_isPortable)
        {
            root = _baseDir;
        }
        else
        {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            root = Path.Combine(appData, "USBAnywhere-Server");
        }

        string fullPath = Path.Combine(root, subFolder);

        if (!Directory.Exists(fullPath))
        {
            try { Directory.CreateDirectory(fullPath); } catch { }
        }

        return fullPath;
    }

    private static bool CheckWriteAccess(string folderPath)
    {
        try
        {
            string tempFile = Path.Combine(folderPath, $".write_test_{Guid.NewGuid():N}");
            using (FileStream fs = File.Create(tempFile, 1, FileOptions.DeleteOnClose)) { }
            return true;
        }
        catch
        {
            return false;
        }
    }

    public static string GetDiagnosticReport()
    {
        return $@"═══════════════════════════════════════════
   USBAnywhere Server Path Diagnostics
═══════════════════════════════════════════
Mode:           {(_isPortable ? "🟢 PORTABLE (USB Ready)" : "🔵 INSTALLED (System Integration)")}
Base Directory: {_baseDir}
Write Access:   {(_hasWriteAccess ? "✅ Yes" : "❌ No")}

Active Paths:
  📁 Logs:   {LogPath}
  🎨 Themes: {ThemePath}
  💾 Data:   {DataPath}
  ⚙️ Config: {ConfigPath}

Driver Location:
  📦 usbipd-win: C:\Program Files\usbipd-win\
═══════════════════════════════════════════";
    }
}
