/*
 * USBAnywhere Server - Logging Service
 * Copyright (c) 2025-2026 oscarlosu-lab
 * https://github.com/oscarlosu-lab/USBAnywhere-Server
 */

using System.IO;
using System.Text;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Centralized logging service with file persistence.
/// </summary>
public static class LogService
{
    private static readonly object _lock = new();
    private static string? _currentLogFile;
    private static bool _initialized;

    public static void Initialize()
    {
        if (_initialized) return;

        try
        {
            string logPath = PathService.LogPath;
            string timestamp = DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss");
            _currentLogFile = Path.Combine(logPath, $"usbanywhere-server_{timestamp}.log");

            WriteToFile($@"
════════════════════════════════════════════════════════════════
 USBAnywhere Server Log - Started {DateTime.Now:yyyy-MM-dd HH:mm:ss}
 Mode: {(PathService.IsPortable ? "Portable" : "Installed")}
════════════════════════════════════════════════════════════════
");
            _initialized = true;
            Info("LogService initialized successfully");
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"LogService init failed: {ex.Message}");
        }
    }

    public static void Debug(string message) => Log("DEBUG", message);
    public static void Info(string message) => Log("INFO", message);
    public static void Warn(string message) => Log("WARN", message);
    public static void Error(string message) => Log("ERROR", message);

    public static void Exception(Exception ex, string? context = null)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"EXCEPTION{(context != null ? $" in {context}" : "")}:");
        sb.AppendLine($"  Type: {ex.GetType().FullName}");
        sb.AppendLine($"  Message: {ex.Message}");
        sb.AppendLine($"  StackTrace:");
        sb.AppendLine(ex.StackTrace);

        if (ex.InnerException != null)
        {
            sb.AppendLine($"  Inner: {ex.InnerException.Message}");
        }

        Log("FATAL", sb.ToString());
    }

    private static void Log(string level, string message)
    {
        string timestamp = DateTime.Now.ToString("HH:mm:ss.fff");
        string logLine = $"[{timestamp}] [{level}] {message}";

        System.Diagnostics.Debug.WriteLine(logLine);
        WriteToFile(logLine);
    }

    private static void WriteToFile(string text)
    {
        if (string.IsNullOrEmpty(_currentLogFile)) return;

        try
        {
            lock (_lock)
            {
                File.AppendAllText(_currentLogFile, text + Environment.NewLine);
            }
        }
        catch { }
    }

    public static string? CurrentLogFile => _currentLogFile;

    public static void CleanupOldLogs(int keepDays = 7)
    {
        try
        {
            string logPath = PathService.LogPath;
            var cutoff = DateTime.Now.AddDays(-keepDays);

            foreach (var file in Directory.GetFiles(logPath, "*.log"))
            {
                if (File.GetCreationTime(file) < cutoff)
                {
                    try { File.Delete(file); } catch { }
                }
            }
        }
        catch { }
    }
}
