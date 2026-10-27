/*
 * USBAnywhere Server - Security Helpers
 * Copyright (c) 2025-2026 oscarlosu-lab
 * https://github.com/oscarlosu-lab/USBAnywhere-Server
 */

using System.Text.RegularExpressions;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Security utilities for input validation and sanitization.
/// </summary>
public static class SecurityHelper
{
    public static bool IsValidBusId(string? busId)
    {
        if (string.IsNullOrWhiteSpace(busId)) return false;
        return Regex.IsMatch(busId, @"^\d+-[\d.]+$");
    }

    public static string SanitizeArgument(string? arg)
    {
        if (string.IsNullOrWhiteSpace(arg)) return string.Empty;
        return Regex.Replace(arg, @"[^a-zA-Z0-9\-._]", "");
    }

    public static bool IsSafePath(string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return false;

        if (path.Contains("..") || path.Contains("//") || path.Contains("\\\\"))
            return false;

        if (path.Contains(';') || path.Contains('&') || path.Contains('|') || 
            path.Contains('$') || path.Contains('`'))
            return false;

        return true;
    }
}
