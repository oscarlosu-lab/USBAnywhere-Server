using System.Security.Cryptography;
using System.Text;

namespace USBAnywhere.Server.Services;

public sealed class PairingService
{
    public const int DefaultTtlSeconds = 900;
    public const int MaxFailedAttempts = 5;

    private readonly object _lock = new();
    private string? _activeCode;
    private DateTime _expiresAtUtc = DateTime.MinValue;
    private int _failedAttempts;

    public (string Code, DateTime ExpiresAtUtc) CreateCode(int ttlSeconds = DefaultTtlSeconds)
    {
        var codeInt = RandomNumberGenerator.GetInt32(0, 1_000_000);
        var code = codeInt.ToString("D6");
        var expires = DateTime.UtcNow.AddSeconds(Math.Clamp(ttlSeconds, 30, 3600));
        lock (_lock)
        {
            _activeCode = code;
            _expiresAtUtc = expires;
            _failedAttempts = 0;
        }
        return (code, expires);
    }

    public string? GetActiveCodeFormatted()
    {
        lock (_lock)
        {
            if (_activeCode == null || DateTime.UtcNow > _expiresAtUtc)
            {
                _activeCode = null;
                return null;
            }
            return $"{_activeCode[..3]}-{_activeCode[3..]}";
        }
    }

    public bool TryRedeem(string? candidateCode)
    {
        var clean = new string((candidateCode ?? "").Where(char.IsDigit).ToArray());
        if (clean.Length != 6) return false;

        lock (_lock)
        {
            if (_activeCode == null || DateTime.UtcNow > _expiresAtUtc)
            {
                _activeCode = null;
                return false;
            }

            var expectedBytes = Encoding.ASCII.GetBytes(_activeCode);
            var actualBytes = Encoding.ASCII.GetBytes(clean);
            if (CryptographicOperations.FixedTimeEquals(expectedBytes, actualBytes))
            {
                _activeCode = null;
                _failedAttempts = 0;
                return true;
            }

            _failedAttempts++;
            if (_failedAttempts >= MaxFailedAttempts)
            {
                _activeCode = null;
            }
            return false;
        }
    }

    public static string GenerateControlToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(16);
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    public static string BuildUa2Token(
        string host,
        int usbipPort,
        string serverName,
        int tlsPort,
        string code,
        string tlsFingerprint)
    {
        var raw = $"{host}|{usbipPort}|{serverName}|{tlsPort}|{code}|{tlsFingerprint}";
        var b64 = Convert.ToBase64String(Encoding.UTF8.GetBytes(raw))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
        return $"UA2:{b64}";
    }
}
