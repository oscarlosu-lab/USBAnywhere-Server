// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Discovery Responder Service (UDP 3241)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

using System.Net;
using System.Net.Sockets;
using System.Text;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Lightweight UDP discovery responder on port 3241 for the USBAnywhere ecosystem.
/// Responds to USBANYWHERE_DISCOVERY_PROBE with USBANYWHERE_SERVER:{MachineName}.
/// </summary>
public class DiscoveryResponderService : IDisposable
{
    private const int DiscoveryPort = 3241;
    private const string ProbeMessage = "USBANYWHERE_DISCOVERY_PROBE";
    private UdpClient? _udpClient;
    private CancellationTokenSource? _cts;
    private bool _isDisposed;

    public void Start()
    {
        if (_udpClient != null) return;

        try
        {
            _cts = new CancellationTokenSource();
            _udpClient = new UdpClient();
            _udpClient.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            _udpClient.Client.Bind(new IPEndPoint(IPAddress.Any, DiscoveryPort));

            Task.Run(() => ListenLoopAsync(_cts.Token));
            LogService.Info($"Discovery responder listening on UDP port {DiscoveryPort}");
        }
        catch (Exception ex)
        {
            LogService.Warn($"Could not start discovery responder on UDP {DiscoveryPort}: {ex.Message}");
        }
    }

    private async Task ListenLoopAsync(CancellationToken token)
    {
        while (!token.IsCancellationRequested && _udpClient != null)
        {
            try
            {
                var result = await _udpClient.ReceiveAsync(token);
                var message = Encoding.UTF8.GetString(result.Buffer).Trim();

                if (message.Contains(ProbeMessage, StringComparison.OrdinalIgnoreCase) ||
                    message.Contains("DISCOVERY", StringComparison.OrdinalIgnoreCase))
                {
                    var response = $"USBANYWHERE_SERVER:{Environment.MachineName}\n";
                    var responseBytes = Encoding.UTF8.GetBytes(response);
                    await _udpClient.SendAsync(responseBytes, responseBytes.Length, result.RemoteEndPoint);
                    LogService.Debug($"Replied to UDP discovery probe from {result.RemoteEndPoint.Address}");
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                if (token.IsCancellationRequested) break;
                LogService.Debug($"Discovery listen loop exception: {ex.Message}");
                await Task.Delay(200, token);
            }
        }
    }

    public void Stop()
    {
        _cts?.Cancel();
        _udpClient?.Dispose();
        _udpClient = null;
        _cts?.Dispose();
        _cts = null;
    }

    public void Dispose()
    {
        if (_isDisposed) return;
        _isDisposed = true;
        Stop();
    }
}
