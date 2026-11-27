/*
 * USBAnywhere Server - Security Helpers
 * Copyright (c) 2025-2026 oscarlosu-lab
 * https://github.com/oscarlosu-lab/USBAnywhere-Server
 */

using System.Net;
using System.Text.RegularExpressions;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Security utilities for input validation and sanitization.
/// </summary>
public static class SecurityHelper
{
    public static bool IsValidBindAddress(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return true;
        var s = value.Trim();
        if (s is "0.0.0.0" or "::" or "*" or "any") return true;
        return IPAddress.TryParse(s, out _);
    }

    public static IPAddress ResolveBindAddress(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return IPAddress.Any;
        var s = value.Trim();
        if (s is "0.0.0.0" or "*" or "any") return IPAddress.Any;
        if (s == "::") return IPAddress.IPv6Any;
        return IPAddress.TryParse(s, out var addr) ? addr : IPAddress.Any;
    }
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
