using System.IO;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Optional TLS 1.2/1.3 tunnel listener forwarding encrypted USB/IP streams to local TCP 3240.
/// </summary>
public sealed class TlsTunnelService : IDisposable
{
    public const int DefaultTlsPort = 3243;

    private readonly int _listenPort;
    private readonly int _targetPort;
    private readonly string? _bindAddressOverride;
    private readonly X509Certificate2 _certificate;
    private TcpListener? _listener;
    private CancellationTokenSource? _cts;
    private bool _disposed;

    public int Port => (_listener?.LocalEndpoint as IPEndPoint)?.Port ?? _listenPort;
    public string CertificateFingerprintSha256 { get; }
    public bool IsRunning => _listener != null && _cts != null && !_cts.IsCancellationRequested;

    public TlsTunnelService(
        int listenPort = DefaultTlsPort,
        int targetPort = 3240,
        string? bindAddress = null,
        X509Certificate2? certificate = null)
    {
        _listenPort = listenPort;
        _targetPort = targetPort;
        _bindAddressOverride = bindAddress;
        _certificate = certificate ?? CreateSelfSignedCertificate(Environment.MachineName);
        CertificateFingerprintSha256 = Convert.ToHexString(_certificate.GetCertHash(HashAlgorithmName.SHA256)).ToLowerInvariant();
    }

    public static X509Certificate2 CreateSelfSignedCertificate(string machineName)
    {
        using var rsa = RSA.Create(2048);
        var req = new CertificateRequest(
            $"CN=USBAnywhere-{SanitizeCn(machineName)}",
            rsa,
            HashAlgorithmName.SHA256,
            RSASignaturePadding.Pkcs1);
        var san = new SubjectAlternativeNameBuilder();
        san.AddDnsName("localhost");
        if (!string.IsNullOrWhiteSpace(machineName))
            san.AddDnsName(SanitizeCn(machineName));
        san.AddIpAddress(IPAddress.Loopback);
        req.CertificateExtensions.Add(san.Build());

        var cert = req.CreateSelfSigned(DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddYears(10));
        return X509CertificateLoader.LoadPkcs12(cert.Export(X509ContentType.Pfx, "usbanywhere"), "usbanywhere");
    }

    private static string SanitizeCn(string s) =>
        new string(s.Where(c => char.IsLetterOrDigit(c) || c == '-' || c == '.').ToArray());

    public void Start()
    {
        if (_cts != null) return;
        _cts = new CancellationTokenSource();
        var bindIp = SecurityHelper.ResolveBindAddress(_bindAddressOverride ?? SettingsService.Current.BindAddress);
        _listener = new TcpListener(bindIp, _listenPort);
        _listener.ExclusiveAddressUse = true;
        try
        {
            _listener.Start();
        }
        catch (SocketException) when (!Equals(bindIp, IPAddress.Any))
        {
            _listener = new TcpListener(IPAddress.Any, _listenPort);
            _listener.ExclusiveAddressUse = true;
            _listener.Start();
        }
        _ = Task.Run(() => AcceptLoopAsync(_cts.Token), _cts.Token);
        LogService.Info($"TLS tunnel listening on {Port} (SHA-256: {CertificateFingerprintSha256[..12]}...)");
    }

    private async Task AcceptLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested && _listener != null)
        {
            try
            {
                var client = await _listener.AcceptTcpClientAsync(ct);
                _ = Task.Run(() => HandleClientAsync(client, ct), ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                if (ct.IsCancellationRequested) break;
                LogService.Debug($"TLS accept error: {ex.Message}");
                await Task.Delay(100, ct);
            }
        }
    }

    private async Task HandleClientAsync(TcpClient client, CancellationToken ct)
    {
        using (client)
        {
            try
            {
                client.NoDelay = true;
                using var ssl = new SslStream(client.GetStream(), leaveInnerStreamOpen: false);
                await ssl.AuthenticateAsServerAsync(new SslServerAuthenticationOptions
                {
                    ServerCertificate = _certificate,
                    ClientCertificateRequired = false,
                    EnabledSslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13,
                    CertificateRevocationCheckMode = X509RevocationMode.NoCheck
                }, ct);

                using var upstream = new TcpClient();
                upstream.NoDelay = true;
                await upstream.ConnectAsync(IPAddress.Loopback, _targetPort, ct);
                using var upStream = upstream.GetStream();

                var t1 = ssl.CopyToAsync(upStream, 65536, ct);
                var t2 = upStream.CopyToAsync(ssl, 65536, ct);
                await Task.WhenAny(t1, t2);
            }
            catch (Exception ex)
            {
                LogService.Debug($"TLS tunnel session closed: {ex.Message}");
            }
        }
    }

    public void Stop()
    {
        _cts?.Cancel();
        try { _listener?.Stop(); } catch { }
        _listener = null;
        _cts?.Dispose();
        _cts = null;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        Stop();
        _certificate.Dispose();
    }
}
