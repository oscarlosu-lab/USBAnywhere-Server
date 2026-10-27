using USBAnywhere.Server.Services;
using Xunit;

namespace USBAnywhere.Server.Tests;

public class NotificationServiceTests
{
    [Fact]
    public void NotificationService_DoesNotThrow_OnAnyNotificationType()
    {
        // Should execute smoothly and fallback safely without unhandled exception
        NotificationService.ShowToast("Server Test", "Device shared", NotificationType.Success);
        NotificationService.ShowToast("Server Warning", "Check driver", NotificationType.Warning);
        NotificationService.ShowToast("Server Info", "Info message", NotificationType.Info);
        NotificationService.ShowToast("Server Error", "Error message", NotificationType.Error);
    }
}
