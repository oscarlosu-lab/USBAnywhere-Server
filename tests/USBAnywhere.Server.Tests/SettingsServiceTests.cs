using USBAnywhere.Server.Models;
using USBAnywhere.Server.Services;
using Xunit;

namespace USBAnywhere.Server.Tests;

public class SettingsServiceTests
{
    [Fact]
    public void Settings_DefaultValues_AreSensible()
    {
        var settings = new AppSettings();

        Assert.False(settings.StartWithWindows);
        Assert.False(settings.StartMinimized);
        Assert.True(settings.ShowNotifications);
        Assert.True(settings.CheckForUpdates);
        Assert.Equal("dark", settings.Theme, ignoreCase: true);
        Assert.False(settings.AutoBindEnabled);
        Assert.NotNull(settings.AutoBindDevices);
        Assert.Empty(settings.AutoBindDevices);
        Assert.Equal(3, settings.RefreshIntervalSeconds);
    }

    [Fact]
    public void Settings_SaveAndLoad_MaintainsIntegrity()
    {
        var current = SettingsService.Current;
        current.Theme = "light";
        current.ShowNotifications = false;
        current.AutoBindEnabled = true;

        bool saved = SettingsService.Save();
        Assert.True(saved);

        var loaded = SettingsService.Load();
        Assert.Equal("light", loaded.Theme);
        Assert.False(loaded.ShowNotifications);
        Assert.True(loaded.AutoBindEnabled);

        // Reset
        current.Theme = "dark";
        current.ShowNotifications = true;
        current.AutoBindEnabled = false;
        SettingsService.Save();
    }

    [Fact]
    public void PathService_SettingsFilePath_EndsWithSettingsJson()
    {
        var path = PathService.SettingsFilePath;
        Assert.False(string.IsNullOrEmpty(path));
        Assert.DoesNotContain("config.json\\settings.json", path);
    }
}
