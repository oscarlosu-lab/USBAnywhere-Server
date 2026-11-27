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

    [Fact]
    public void SecurityHelper_BindAddressValidationAndResolution()
    {
        Assert.True(SecurityHelper.IsValidBindAddress(""));
        Assert.True(SecurityHelper.IsValidBindAddress("0.0.0.0"));
        Assert.True(SecurityHelper.IsValidBindAddress("100.64.0.10"));
        Assert.True(SecurityHelper.IsValidBindAddress("::1"));
        Assert.False(SecurityHelper.IsValidBindAddress("bad-ip"));
        Assert.Equal(IPAddress.Any, SecurityHelper.ResolveBindAddress(""));
        Assert.Equal(IPAddress.Parse("100.64.0.10"), SecurityHelper.ResolveBindAddress("100.64.0.10"));
    }

    [Fact]
    public void UsbipdService_ExtractRevisionFromDeviceId_ParsesHexRev()
    {
        Assert.Equal("0200", UsbipdService.ExtractRevisionFromDeviceId(@"USB\VID_0529&PID_0001&REV_0200\6&1234"));
        Assert.Equal("", UsbipdService.ExtractRevisionFromDeviceId(@"USB\VID_0529&PID_0001\6&1234"));
    }

    [Fact]
    public async Task DiscoveryResponderService_BindsSpecificLoopbackAddress()
    {
        using var service = new DiscoveryResponderService(port: 0, bindAddress: "127.0.0.1");
        service.Start();
        Assert.Equal(IPAddress.Loopback, service.BoundAddress);
        using var tcp = new TcpClient();
        await tcp.ConnectAsync(IPAddress.Loopback, service.Port);
        var cmd = Encoding.UTF8.GetBytes("STATUS\n");
        await tcp.GetStream().WriteAsync(cmd, 0, cmd.Length);
        using var reader = new StreamReader(tcp.GetStream(), Encoding.UTF8);
        var json = await reader.ReadLineAsync();
        Assert.Contains("\"status\":\"OK\"", json);
    }

    [Fact]
    public void FirewallService_BuildTcpRuleArguments_IncludesBindIpAndTlsPort()
    {
        var args = FirewallService.BuildTcpRuleArguments("USBAnywhere Server", "remoteip=10.0.0.5", "100.64.0.1", includeTlsPort: true);
        Assert.Contains("localport=3240,3241,3243", args);
        Assert.Contains("localip=100.64.0.1", args);
    }

    [Fact]
    public async Task PairingService_SingleUseRedeem_AndLockoutAfterFiveFailures()
    {
        var pairing = new PairingService();
        var (code, _) = pairing.CreateCode();
        Assert.Equal(6, code.Length);
        Assert.True(pairing.TryRedeem(code));
        Assert.False(pairing.TryRedeem(code)); // single use

        var (code2, _) = pairing.CreateCode();
        for (int i = 0; i < 5; i++) Assert.False(pairing.TryRedeem("000000" == code2 ? "111111" : "000000"));
        Assert.False(pairing.TryRedeem(code2)); // locked out

        // Live TCP PAIR test
        var (code3, _) = pairing.CreateCode();
        using var svc = new DiscoveryResponderService(port: 0, bindAddress: "127.0.0.1", pairingService: pairing);
        svc.Start();
        using var tcp = new TcpClient();
        await tcp.ConnectAsync(IPAddress.Loopback, svc.Port);
        var req = Encoding.UTF8.GetBytes($"PAIR {code3}\n");
        await tcp.GetStream().WriteAsync(req);
        using var r = new StreamReader(tcp.GetStream(), Encoding.UTF8);
        var resp = await r.ReadLineAsync();
        Assert.Contains("\"status\":\"OK\"", resp);
        Assert.Contains("\"tls_port\":", resp);
    }

    [Fact]
    public void TlsTunnelService_GeneratesSha256Fingerprint()
    {
        using var tls = new TlsTunnelService(listenPort: 0, targetPort: 3240, bindAddress: "127.0.0.1");
        Assert.Equal(64, tls.CertificateFingerprintSha256.Length);
    }

    [Fact]
    public void SessionIsolationService_EnforcesPortOwnershipAndAutoConnect()
    {
        var iso = new USBAnywhere.Server.Services.SessionIsolationService();
        iso.RegisterPortOwner(1, sessionId: 1);
        Assert.True(iso.CanSessionControlPort(1, sessionId: 1, enforceIsolation: true));
        Assert.False(iso.CanSessionControlPort(1, sessionId: 2, enforceIsolation: true));
        Assert.False(USBAnywhere.Server.Services.SessionIsolationService.EvaluateAutoConnect(false, true));
        Assert.True(USBAnywhere.Server.Services.SessionIsolationService.EvaluateAutoConnect(false, false));
    }
}
