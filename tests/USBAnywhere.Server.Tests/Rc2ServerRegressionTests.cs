using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using USBAnywhere.Server.Services;
using Xunit;

namespace USBAnywhere.Server.Tests;

public class Rc2ServerRegressionTests
{
    [Fact]
    public async Task DiscoveryResponder_Pair_ReturnsTokenAndControlTokenAliases()
    {
        var pairing = new PairingService();
        int port;
        using (var probe = new TcpListener(IPAddress.Loopback, 0))
        {
            probe.Start();
            port = ((IPEndPoint)probe.LocalEndpoint).Port;
        }

        using var disc = new DiscoveryResponderService(
            usbipdService: null,
            port: port,
            bindAddress: "127.0.0.1",
            pairingService: pairing,
            tlsFingerprintProvider: () => "abcd");
        disc.Start();

        var code = pairing.CreateCode().Code;
        using var tcp = new TcpClient();
        await tcp.ConnectAsync(IPAddress.Loopback, port);
        using var s = tcp.GetStream();
        await s.WriteAsync(Encoding.UTF8.GetBytes($"PAIR {code} TEST\n"));
        await s.FlushAsync();

        using var r = new StreamReader(s, Encoding.UTF8);
        var line = await r.ReadLineAsync();
        Assert.False(string.IsNullOrWhiteSpace(line));
        using var doc = JsonDocument.Parse(line!);
        Assert.Equal("OK", doc.RootElement.GetProperty("status").GetString());
        Assert.True(doc.RootElement.TryGetProperty("token", out var tok));
        Assert.True(doc.RootElement.TryGetProperty("control_token", out var ctok));
        Assert.Equal(tok.GetString(), ctok.GetString());
        Assert.True(doc.RootElement.TryGetProperty("server_name", out _));
    }

    [Fact]
    public async Task TlsTunnelService_SurvivesNonTlsSlowlorisGarbage()
    {
        using var target = new TcpListener(IPAddress.Loopback, 0);
        target.Start();
        int targetPort = ((IPEndPoint)target.LocalEndpoint).Port;

        int tlsPort;
        using (var probe = new TcpListener(IPAddress.Loopback, 0))
        {
            probe.Start();
            tlsPort = ((IPEndPoint)probe.LocalEndpoint).Port;
        }

        using var tls = new TlsTunnelService(listenPort: tlsPort, targetPort: targetPort, bindAddress: "127.0.0.1");
        tls.Start();

        using var garbage = new TcpClient();
        await garbage.ConnectAsync(IPAddress.Loopback, tlsPort);
        await garbage.GetStream().WriteAsync(Encoding.ASCII.GetBytes("GARBAGE"));

        using var probeOk = new TcpClient();
        await probeOk.ConnectAsync(IPAddress.Loopback, tlsPort);
        Assert.True(probeOk.Connected);
    }
}
