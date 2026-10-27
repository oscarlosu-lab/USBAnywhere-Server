using USBAnywhere.Server.Models;
using USBAnywhere.Server.Services;
using Xunit;

namespace USBAnywhere.Server.Tests;

public class LocalizationServiceTests
{
    private readonly LocalizationService _loc = new();

    [Theory]
    [InlineData("es", "title", "USBAnywhere Server")]
    [InlineData("es", "btn_share", "📤 Compartir")]
    [InlineData("es", "btn_stop", "🚫 Detener")]
    [InlineData("es", "col_busid", "Bus ID")]
    [InlineData("es", "col_type", "Tipo")]
    [InlineData("es", "type_keyboard", "Teclado")]
    [InlineData("es", "type_mouse", "Ratón")]
    [InlineData("es", "status_running", "Servidor activo en puerto 3240 (usbipd corriendo)")]
    [InlineData("es", "settings_title", "⚙️ Ajustes - USBAnywhere Server")]
    [InlineData("es", "chk_autobind", "Activar Auto-Bind para dispositivos compartidos")]
    [InlineData("en", "title", "USBAnywhere Server")]
    [InlineData("en", "btn_share", "📤 Share")]
    [InlineData("en", "btn_stop", "🚫 Stop")]
    [InlineData("en", "col_busid", "Bus ID")]
    [InlineData("en", "col_type", "Type")]
    [InlineData("en", "type_keyboard", "Keyboard")]
    [InlineData("en", "type_mouse", "Mouse")]
    [InlineData("en", "status_running", "Server running on port 3240 (usbipd active)")]
    [InlineData("en", "settings_title", "⚙️ Settings - USBAnywhere Server")]
    [InlineData("en", "chk_autobind", "Enable Auto-Bind for shared devices")]
    public void LocalizationService_ReturnsCorrectTranslations(string lang, string key, string expected)
    {
        var text = _loc.GetText(key, lang);
        Assert.Equal(expected, text);
    }

    [Fact]
    public void LocalizationService_FormattedTextWorks()
    {
        var formattedEs = _loc.GetFormattedText("device_count", "es", 5);
        Assert.Equal("5 dispositivo(s)", formattedEs);

        var formattedEn = _loc.GetFormattedText("device_count", "en", 5);
        Assert.Equal("5 device(s)", formattedEn);

        var formattedIp = _loc.GetFormattedText("diag_server_ip", "es", "192.168.1.100");
        Assert.Contains("192.168.1.100:3240", formattedIp);
    }

    [Fact]
    public void LocalizationService_FallbackToEnglish()
    {
        var fallback = _loc.GetText("btn_share", "fr");
        Assert.Equal("📤 Share", fallback);
    }

    [Fact]
    public void LocalUsbDevice_BilingualProperties_ReactToLanguageChange()
    {
        var device = new LocalUsbDevice
        {
            VendorId = 0x046D,
            ProductId = 0xC52B,
            Description = "Logitech USB Receiver Mouse",
            Status = "Not shared"
        };

        device.SetLanguage("es");
        Assert.Equal("Ratón", device.LocalizedTypeName);
        Assert.Equal("No compartido", device.LocalizedStatus);
        Assert.Equal("📤 Compartir", device.ShareButtonText);
        Assert.Equal("🚫 Detener", device.StopButtonText);

        device.SetLanguage("en");
        Assert.Equal("Mouse", device.LocalizedTypeName);
        Assert.Equal("Not shared", device.LocalizedStatus);
        Assert.Equal("📤 Share", device.ShareButtonText);
        Assert.Equal("🚫 Stop", device.StopButtonText);
    }
}
