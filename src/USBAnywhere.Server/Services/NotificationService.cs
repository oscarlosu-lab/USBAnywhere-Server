using System;
using System.Diagnostics;
using Microsoft.Toolkit.Uwp.Notifications;
using WinForms = System.Windows.Forms;

namespace USBAnywhere.Server.Services;

public enum NotificationType
{
    Info,
    Success,
    Warning,
    Error
}

/// <summary>
/// Modern Windows Toast Notification Service for USBAnywhere Server
/// with graceful fallback to NotifyIcon balloon tips.
/// </summary>
public static class NotificationService
{
    public static void ShowToast(string title, string message, NotificationType type = NotificationType.Info, WinForms.NotifyIcon? fallbackIcon = null)
    {
        if (!SettingsService.Current.ShowNotifications)
            return;

        try
        {
            var iconPrefix = type switch
            {
                NotificationType.Success => "✅ ",
                NotificationType.Warning => "⚠️ ",
                NotificationType.Error => "❌ ",
                _ => "🌐 "
            };

            new ToastContentBuilder()
                .AddText($"{iconPrefix}{title}")
                .AddText(message)
                .AddAttributionText("USBAnywhere Server v3.0")
                .Show();
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"[Toast] Failed to show Windows toast: {ex.Message}. Falling back to BalloonTip.");
            try
            {
                var tipIcon = type switch
                {
                    NotificationType.Warning => WinForms.ToolTipIcon.Warning,
                    NotificationType.Error => WinForms.ToolTipIcon.Error,
                    _ => WinForms.ToolTipIcon.Info
                };
                fallbackIcon?.ShowBalloonTip(3000, title, message, tipIcon);
            }
            catch
            {
                // Ignore secondary failure
            }
        }
    }
}
