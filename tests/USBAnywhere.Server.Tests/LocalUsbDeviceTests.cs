using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
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

    [Fact]
    public async Task DiscoveryResponderService_TcpAndUdpControlApi_RespondsValidJson()
    {
        using var service = new DiscoveryResponderService(port: 13241);
        service.Start();
        var activePort = service.Port;
        await Task.Delay(100);

        // Test TCP STATUS
        using (var tcp = new TcpClient())
        {
            await tcp.ConnectAsync(IPAddress.Loopback, activePort);
            var stream = tcp.GetStream();
            var cmd = Encoding.UTF8.GetBytes("STATUS\n");
            await stream.WriteAsync(cmd, 0, cmd.Length);
            using var reader = new StreamReader(stream, Encoding.UTF8);
            var json = await reader.ReadLineAsync();
            Assert.NotNull(json);
            Assert.Contains("\"status\":\"OK\"", json);
            Assert.Contains("\"platform\":\"windows\"", json);
        }

        // Test TCP LIST
        using (var tcp = new TcpClient())
        {
            await tcp.ConnectAsync(IPAddress.Loopback, activePort);
            var stream = tcp.GetStream();
            var cmd = Encoding.UTF8.GetBytes("LIST\n");
            await stream.WriteAsync(cmd, 0, cmd.Length);
            using var reader = new StreamReader(stream, Encoding.UTF8);
            var json = await reader.ReadLineAsync();
            Assert.NotNull(json);
            Assert.Contains("\"status\":\"OK\"", json);
            Assert.Contains("\"devices\":", json);
        }
    }
}
