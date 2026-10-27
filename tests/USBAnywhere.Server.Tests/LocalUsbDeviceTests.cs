using USBAnywhere.Server.Models;
using USBAnywhere.Server.Services;
using Xunit;

namespace USBAnywhere.Server.Tests;

public class LocalUsbDeviceTests
{
    [Fact]
    public void LocalUsbDevice_VidPid_FormattedCorrectly()
    {
        var device = new LocalUsbDevice
        {
            VendorId = 0x0781,
            ProductId = 0x5567,
            BusId = "1-1",
            Name = "SanDisk Cruzer Blade",
            Description = "Mass Storage Device"
        };

        Assert.Equal("0781:5567", device.VidPid);
        Assert.Contains("1-1", device.ToString());
        Assert.Contains("0781:5567", device.ToString());
    }

    [Fact]
    public void LocalUsbDevice_PropertyChanged_FiresOnStatusChange()
    {
        var device = new LocalUsbDevice
        {
            VendorId = 0x046D,
            ProductId = 0xC52B,
            Status = "Not shared"
        };

        string? changedProperty = null;
        device.PropertyChanged += (s, e) => changedProperty = e.PropertyName;

        device.Status = "Shared";
        Assert.Equal(nameof(LocalUsbDevice.Status), changedProperty);

        device.IsExported = true;
        Assert.Equal(nameof(LocalUsbDevice.IsExported), changedProperty);
    }

    [Theory]
    [InlineData("USB-SERIAL CH340", "Serial / UART")]
    [InlineData("Realtek USB 2.0 Camera", "Camera")]
    [InlineData("SanDisk Mass Storage", "Storage")]
    [InlineData("Logitech USB Receiver Mouse", "Mouse")]
    public void DeviceIconHelper_DetectsDeviceTypesCorrectly(string description, string expectedType)
    {
        var typeName = DeviceIconHelper.GetTypeName(0, 0, description);
        Assert.Equal(expectedType, typeName);
    }
}
