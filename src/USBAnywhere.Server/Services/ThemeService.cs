using System.Windows;
using Media = System.Windows.Media;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Theme service - Obsidian Precision (v3.2.0) / Light theme management using DynamicResource
/// </summary>
public static class ThemeService
{
    public static void ApplyTheme(string? theme)
    {
        if (System.Windows.Application.Current == null) return;
        var resources = System.Windows.Application.Current.Resources;
        bool isLight = string.Equals(theme, "light", StringComparison.OrdinalIgnoreCase);

        if (isLight)
        {
            resources["BgPrimary"] = new Media.SolidColorBrush(ColorFromHex("#F4F4F6"));
            resources["BgSecondary"] = new Media.SolidColorBrush(ColorFromHex("#FFFFFF"));
            resources["BgTertiary"] = new Media.SolidColorBrush(ColorFromHex("#EAEAEF"));
            resources["AccentColor"] = new Media.SolidColorBrush(ColorFromHex("#111827"));
            resources["AccentHover"] = new Media.SolidColorBrush(ColorFromHex("#374151"));
            resources["HighlightColor"] = new Media.SolidColorBrush(ColorFromHex("#EF4444"));
            resources["TextPrimary"] = new Media.SolidColorBrush(ColorFromHex("#111827"));
            resources["TextSecondary"] = new Media.SolidColorBrush(ColorFromHex("#6B7280"));
            resources["BorderColor"] = new Media.SolidColorBrush(ColorFromHex("#E5E7EB"));
            resources["StatusSuccess"] = new Media.SolidColorBrush(ColorFromHex("#16A34A"));
            resources["StatusWarning"] = new Media.SolidColorBrush(ColorFromHex("#D97706"));
            resources["StatusError"] = new Media.SolidColorBrush(ColorFromHex("#DC2626"));
            resources["StatusInfo"] = new Media.SolidColorBrush(ColorFromHex("#4B5563"));
            resources["DataGridBg"] = new Media.SolidColorBrush(ColorFromHex("#FFFFFF"));
            resources["DataGridAltBg"] = new Media.SolidColorBrush(ColorFromHex("#F9FAFB"));
            resources["DataGridHover"] = new Media.SolidColorBrush(ColorFromHex("#F3F4F6"));
            resources["DataGridSelected"] = new Media.SolidColorBrush(ColorFromHex("#E5E7EB"));
        }
        else
        {
            // Obsidian Precision Dark Theme (v3.2.0)
            resources["BgPrimary"] = new Media.SolidColorBrush(ColorFromHex("#0B0C0E"));
            resources["BgSecondary"] = new Media.SolidColorBrush(ColorFromHex("#131417"));
            resources["BgTertiary"] = new Media.SolidColorBrush(ColorFromHex("#16171B"));
            resources["AccentColor"] = new Media.SolidColorBrush(ColorFromHex("#D2F800"));
            resources["AccentHover"] = new Media.SolidColorBrush(ColorFromHex("#B8DA00"));
            resources["HighlightColor"] = new Media.SolidColorBrush(ColorFromHex("#EF4444"));
            resources["TextPrimary"] = new Media.SolidColorBrush(ColorFromHex("#EDEDED"));
            resources["TextSecondary"] = new Media.SolidColorBrush(ColorFromHex("#8E919A"));
            resources["BorderColor"] = new Media.SolidColorBrush(ColorFromHex("#22242A"));
            resources["StatusSuccess"] = new Media.SolidColorBrush(ColorFromHex("#D2F800"));
            resources["StatusWarning"] = new Media.SolidColorBrush(ColorFromHex("#F59E0B"));
            resources["StatusError"] = new Media.SolidColorBrush(ColorFromHex("#EF4444"));
            resources["StatusInfo"] = new Media.SolidColorBrush(ColorFromHex("#A1A1AA"));
            resources["DataGridBg"] = new Media.SolidColorBrush(ColorFromHex("#0B0C0E"));
            resources["DataGridAltBg"] = new Media.SolidColorBrush(ColorFromHex("#131417"));
            resources["DataGridHover"] = new Media.SolidColorBrush(ColorFromHex("#18191E"));
            resources["DataGridSelected"] = new Media.SolidColorBrush(ColorFromHex("#22242A"));
        }
    }

    private static Media.Color ColorFromHex(string hex)
    {
        return (Media.Color)Media.ColorConverter.ConvertFromString(hex);
    }

    public static string GetThemeIcon(string? theme)
    {
        return string.Equals(theme, "light", StringComparison.OrdinalIgnoreCase) ? "☀️" : "🌙";
    }
}
