// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Discovery & Dynamic Control Service (UDP/TCP 3241)
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace USBAnywhere.Server.Services;

/// <summary>
/// UDP discovery responder and TCP Dynamic Control API on port 3241 for the USBAnywhere v3.2.0 ecosystem.
/// - UDP 3241: Responds to USBANYWHERE_DISCOVERY_PROBE with USBANYWHERE_SERVER:{MachineName}.
/// - TCP 3241: Handles LIST, BIND <busid>, UNBIND <busid>, STATUS commands for On-Demand binding.
/// </summary>
public class DiscoveryResponderService : IDisposable
{
    public const int CONTROL_PORT = 3241;
    private const string ProbeMessage = "USBANYWHERE_DISCOVERY_PROBE";
    private const int MaxCommandBytes = 512;

    private readonly UsbipdService? _usbipdService;
    private readonly Action? _onStateChanged;
    private readonly int _port;
    private readonly string? _bindAddressOverride;
    private readonly PairingService _pairingService;
    private readonly Func<string?>? _tlsFingerprintProvider;
    private readonly SemaphoreSlim _clientConcurrency = new(8, 8);
    private UdpClient? _udpClient;
    private TcpListener? _tcpListener;
    private CancellationTokenSource? _cts;
    private bool _isDisposed;

    public int Port => (_tcpListener?.LocalEndpoint as IPEndPoint)?.Port ?? _port;
    public IPAddress BoundAddress { get; private set; } = IPAddress.Any;
    public PairingService Pairing => _pairingService;

    public DiscoveryResponderService(
        UsbipdService? usbipdService = null,
        Action? onStateChanged = null,
        int port = CONTROL_PORT,
        string? bindAddress = null,
        PairingService? pairingService = null,
        Func<string?>? tlsFingerprintProvider = null)
    {
        _usbipdService = usbipdService;
        _onStateChanged = onStateChanged;
        _port = port;
        _bindAddressOverride = bindAddress;
        _pairingService = pairingService ?? new PairingService();
        _tlsFingerprintProvider = tlsFingerprintProvider;
    }

    public void Start()
    {
        if (_cts != null) return;
        _cts = new CancellationTokenSource();
        var targetIp = SecurityHelper.ResolveBindAddress(_bindAddressOverride ?? SettingsService.Current.BindAddress);
        BoundAddress = targetIp;

        try
        {
            _udpClient = new UdpClient(targetIp.AddressFamily);
            _udpClient.ExclusiveAddressUse = true;
            try
            {
                _udpClient.Client.Bind(new IPEndPoint(targetIp, _port));
            }
            catch (SocketException) when (!Equals(targetIp, IPAddress.Any))
            {
                _udpClient.Dispose();
                _udpClient = new UdpClient();
                _udpClient.ExclusiveAddressUse = true;
                _udpClient.Client.Bind(new IPEndPoint(IPAddress.Any, _port));
                BoundAddress = IPAddress.Any;
            }
            Task.Run(() => ListenUdpLoopAsync(_cts.Token));
            LogService.Info($"Discovery responder listening on UDP {BoundAddress}:{_port}");
        }
        catch (Exception ex)
        {
            LogService.Warn($"Could not start discovery responder on UDP {_port}: {ex.Message}");
        }

        try
        {
            var listenIp = targetIp;
            _tcpListener = new TcpListener(listenIp, _port);
            _tcpListener.ExclusiveAddressUse = true;
            try
            {
                _tcpListener.Start();
            }
            catch (SocketException) when (!Equals(listenIp, IPAddress.Any))
            {
                _tcpListener = new TcpListener(IPAddress.Any, _port);
                _tcpListener.ExclusiveAddressUse = true;
                _tcpListener.Start();
                listenIp = IPAddress.Any;
            }
            BoundAddress = listenIp;
            Task.Run(() => ListenTcpLoopAsync(_cts.Token));
            LogService.Info($"Dynamic Control API listening on TCP {BoundAddress}:{Port}");
        }
        catch (Exception ex)
        {
            LogService.Warn($"Could not start Dynamic Control API on TCP {_port}: {ex.Message}");
        }
    }

    public void Restart()
    {
        Stop();
        Start();
    }

    private async Task ListenUdpLoopAsync(CancellationToken token)
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

    private async Task ListenTcpLoopAsync(CancellationToken token)
    {
        while (!token.IsCancellationRequested && _tcpListener != null)
        {
            try
            {
                var client = await _tcpListener.AcceptTcpClientAsync(token);
                _ = Task.Run(() => HandleTcpClientAsync(client, token), token);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                if (token.IsCancellationRequested) break;
                LogService.Debug($"Dynamic Control TCP accept error: {ex.Message}");
                await Task.Delay(200, token);
            }
        }
    }

    private async Task HandleTcpClientAsync(TcpClient client, CancellationToken token)
    {
        using (client)
        {
            bool acquired = false;
            try
            {
                using var cts = CancellationTokenSource.CreateLinkedTokenSource(token);
                cts.CancelAfter(10000);

                acquired = await _clientConcurrency.WaitAsync(TimeSpan.FromSeconds(2), cts.Token);
                if (!acquired)
                {
                    return;
                }

                if (SettingsService.Current.WhitelistEnabled &&
                    client.Client.RemoteEndPoint is IPEndPoint remoteEp &&
                    !IPAddress.IsLoopback(remoteEp.Address))
                {
                    // Allow PAIR before IP whitelist check when an active code exists
                }

                var stream = client.GetStream();
                var buffer = new byte[MaxCommandBytes];
                int totalRead = 0;
                while (totalRead < buffer.Length)
                {
                    int read = await stream.ReadAsync(buffer.AsMemory(totalRead, buffer.Length - totalRead), cts.Token);
                    if (read <= 0) break;
                    totalRead += read;
                    if (Array.IndexOf(buffer, (byte)'\n', totalRead - read, read) >= 0) break;
                }

                if (totalRead == 0) return;
                var rawText = Encoding.UTF8.GetString(buffer, 0, totalRead);
                var newlineIdx = rawText.IndexOf('\n');
                var line = (newlineIdx >= 0 ? rawText[..newlineIdx] : rawText).Trim();
                if (string.IsNullOrEmpty(line)) return;

                var preParts = line.Split(' ', 3, StringSplitOptions.RemoveEmptyEntries);
                var preCmd = preParts[0].ToUpperInvariant();
                if (preCmd == "PAIR" && preParts.Length >= 2)
                {
                    if (_pairingService.TryRedeem(preParts[1]))
                    {
                        var remoteIp = (client.Client.RemoteEndPoint as IPEndPoint)?.Address.ToString();
                        if (!string.IsNullOrWhiteSpace(remoteIp) &&
                            SettingsService.Current.WhitelistEnabled &&
                            !SettingsService.Current.WhitelistedIPs.Contains(remoteIp, StringComparer.OrdinalIgnoreCase))
                        {
                            SettingsService.Current.WhitelistedIPs.Add(remoteIp);
                        }
                        if (string.IsNullOrWhiteSpace(SettingsService.Current.ControlToken))
                        {
                            SettingsService.Current.ControlToken = PairingService.GenerateControlToken();
                        }
                        SettingsService.Save();
                        var fp = _tlsFingerprintProvider?.Invoke() ?? "";
                        await WriteJsonAsync(stream, new
                        {
                            status = "OK",
                            server = Environment.MachineName,
                            token = SettingsService.Current.ControlToken,
                            usbip_port = 3240,
                            tls_port = SettingsService.Current.TlsPort,
                            tls_fingerprint = fp
                        }, cts.Token);
                    }
                    else
                    {
                        await WriteJsonAsync(stream, new { status = "DENIED", message = "Invalid or expired pairing code" }, cts.Token);
                    }
                    return;
                }

                if (SettingsService.Current.WhitelistEnabled &&
                    client.Client.RemoteEndPoint is IPEndPoint wlEp &&
                    !IPAddress.IsLoopback(wlEp.Address))
                {
                    var remoteIp = wlEp.Address.ToString();
                    if (SettingsService.Current.WhitelistedIPs.Count == 0 ||
                        !SettingsService.Current.WhitelistedIPs.Contains(remoteIp, StringComparer.OrdinalIgnoreCase))
                    {
                        await WriteJsonAsync(stream, new
                        {
                            status = "DENIED",
                            message = $"Client IP {remoteIp} is not in server whitelist"
                        }, cts.Token);
                        return;
                    }
                }

                var parts = line.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
                var expectedTok = (SettingsService.Current.ControlToken ?? "").Trim();
                if (!string.IsNullOrEmpty(expectedTok))
                {
                    if (parts.Length >= 2 && string.Equals(parts[0], "TOKEN", StringComparison.OrdinalIgnoreCase))
                    {
                        var tokAndRest = parts[1].Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
                        if (tokAndRest.Length >= 2 &&
                            System.Security.Cryptography.CryptographicOperations.FixedTimeEquals(
                                Encoding.UTF8.GetBytes(tokAndRest[0]),
                                Encoding.UTF8.GetBytes(expectedTok)))
                        {
                            parts = tokAndRest[1].Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
                        }
                        else
                        {
                            await WriteJsonAsync(stream, new { status = "DENIED", message = "Invalid control token" }, cts.Token);
                            return;
                        }
                    }
                    else if (!(client.Client.RemoteEndPoint is IPEndPoint epLoop && IPAddress.IsLoopback(epLoop.Address)))
                    {
                        await WriteJsonAsync(stream, new { status = "DENIED", message = "Control token required" }, cts.Token);
                        return;
                    }
                }
                var cmd = parts[0].ToUpperInvariant();
                var arg = parts.Length > 1 ? parts[1].Trim() : "";

                if (cmd == "LIST")
                {
                    var lines = new List<string>();
                    if (_usbipdService != null)
                    {
                        var devs = await _usbipdService.GetDevicesAsync();
                        foreach (var d in devs)
                        {
                            var tag = d.IsExported ? $"[{d.Status}]" : "[Local]";
                            var revTag = string.IsNullOrEmpty(d.Revision) ? "" : $" [Rev:{d.Revision}]";
                            lines.Add($"{d.BusId} : {d.DisplayName} {tag} ({d.VidPid.ToLowerInvariant()}){revTag}");
                        }
                    }
                    await WriteJsonAsync(stream, new { status = "OK", devices = lines }, cts.Token);
                }
                else if (cmd == "BIND" && !string.IsNullOrEmpty(arg))
                {
                    if (!SecurityHelper.IsValidBusId(arg))
                    {
                        await WriteJsonAsync(stream, new { status = "ERROR", message = "Invalid BusId" }, cts.Token);
                        return;
                    }

                    if (_usbipdService != null)
                    {
                        var devs = await _usbipdService.GetDevicesAsync();
                        var targetDev = devs.FirstOrDefault(d => string.Equals(d.BusId, arg, StringComparison.OrdinalIgnoreCase));
                        if (targetDev != null)
                        {
                            var typeName = targetDev.TypeName ?? "";
                            var desc = $"{targetDev.Name} {targetDev.Description}";
                            bool isHub = typeName.Contains("Hub", StringComparison.OrdinalIgnoreCase) ||
                                         desc.Contains("USB Hub", StringComparison.OrdinalIgnoreCase);
                            bool isHidInput = typeName.Contains("Keyboard", StringComparison.OrdinalIgnoreCase) ||
                                              typeName.Contains("Mouse", StringComparison.OrdinalIgnoreCase) ||
                                              desc.Contains("Keyboard", StringComparison.OrdinalIgnoreCase) ||
                                              desc.Contains("Mouse", StringComparison.OrdinalIgnoreCase);
                            bool explicitlyAllowed = SettingsService.Current.AutoBindDevices.Contains(targetDev.VidPid, StringComparer.OrdinalIgnoreCase);

                            if (isHub || (isHidInput && !explicitlyAllowed))
                            {
                                await WriteJsonAsync(stream, new
                                {
                                    status = "DENIED",
                                    busid = arg,
                                    message = $"Remote bind blocked for protected host device ({typeName})"
                                }, cts.Token);
                                return;
                            }
                        }
                    }

                    bool ok = _usbipdService != null && await _usbipdService.BindDeviceAsync(arg);
                    _onStateChanged?.Invoke();
                    await WriteJsonAsync(stream, new
                    {
                        status = ok ? "OK" : "ERROR",
                        busid = arg,
                        message = ok ? "Bound on demand" : "Failed to bind device"
                    }, cts.Token);
                }
                else if (cmd == "UNBIND" && !string.IsNullOrEmpty(arg))
                {
                    if (!SecurityHelper.IsValidBusId(arg))
                    {
                        await WriteJsonAsync(stream, new { status = "ERROR", message = "Invalid BusId" }, cts.Token);
                        return;
                    }

                    bool ok = _usbipdService != null && await _usbipdService.UnbindDeviceAsync(arg);
                    _onStateChanged?.Invoke();
                    await WriteJsonAsync(stream, new
                    {
                        status = ok ? "OK" : "ERROR",
                        busid = arg
                    }, cts.Token);
                }
                else if (cmd == "STATUS")
                {
                    var devs = _usbipdService != null ? await _usbipdService.GetDevicesAsync() : new();
                    var version = typeof(DiscoveryResponderService).Assembly.GetName().Version?.ToString(3) ?? "3.4.0";
                    await WriteJsonAsync(stream, new
                    {
                        status = "OK",
                        platform = "windows",
                        version,
                        hostname = Environment.MachineName,
                        total_devices = devs.Count,
                        exported_count = devs.Count(d => d.IsExported)
                    }, cts.Token);
                }
                else
                {
                    await WriteJsonAsync(stream, new { status = "ERROR", message = "Unknown command" }, cts.Token);
                }
            }
            catch (Exception ex)
            {
                LogService.Debug($"Dynamic Control client error: {ex.Message}");
            }
            finally
            {
                if (acquired)
                {
                    _clientConcurrency.Release();
                }
            }
        }
    }

    private static async Task WriteJsonAsync(NetworkStream stream, object payload, CancellationToken token)
    {
        var json = JsonSerializer.Serialize(payload) + "\n";
        var bytes = Encoding.UTF8.GetBytes(json);
        await stream.WriteAsync(bytes, 0, bytes.Length, token);
        await stream.FlushAsync(token);
    }

    public void Stop()
    {
        _cts?.Cancel();
        try { _tcpListener?.Stop(); } catch (Exception ex) { LogService.Debug($"Discovery cleanup: {ex.Message}"); }
        _tcpListener = null;
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
