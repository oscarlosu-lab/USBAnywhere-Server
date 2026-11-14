using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;

namespace USBAnywhere.Server.Services;

/// <summary>
/// Update service - Check for updates against GitHub releases with mandatory fail-closed SHA-256 verification.
/// Supports both Installed (.exe Setup) and Portable (.zip) update flows.
/// Copyright (c) 2025-2026 oscarlosu-lab
/// </summary>
public class UpdateService
{
    private const string GITHUB_REPO = "oscarlosu-lab/USBAnywhere-Server";
    private const string GITHUB_MONOREPO = "oscarlosu-lab/USBAnywhere";
    private static readonly string APP_VERSION = System.Reflection.Assembly.GetExecutingAssembly()
        .GetName().Version?.ToString(3) ?? "3.3.1";

    public async Task<UpdateInfo> CheckForUpdatesAsync()
    {
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
            client.DefaultRequestHeaders.Add("User-Agent", $"USBAnywhere-Server/{APP_VERSION}");

            string? response = null;
            foreach (var repo in new[] { GITHUB_REPO, GITHUB_MONOREPO })
            {
                var apiUrl = $"https://api.github.com/repos/{repo}/releases/latest";
                using var res = await client.GetAsync(apiUrl);
                if (res.StatusCode == System.Net.HttpStatusCode.NotFound)
                    continue;

                res.EnsureSuccessStatusCode();
                response = await res.Content.ReadAsStringAsync();
                break;
            }

            if (string.IsNullOrWhiteSpace(response))
            {
                return new UpdateInfo { UpdateAvailable = false, CurrentVersion = APP_VERSION };
            }

            using var doc = JsonDocument.Parse(response);
            var root = doc.RootElement;

            var tagName = root.TryGetProperty("tag_name", out var tagProp) ? tagProp.GetString() : null;
            var releaseBody = root.TryGetProperty("body", out var bodyProp) ? bodyProp.GetString() : null;
            var latestVersion = tagName?.TrimStart('v') ?? "0.0.0";
            var currentVersion = APP_VERSION;

            var canParseLatest = Version.TryParse(latestVersion, out var latest);
            var canParseCurrent = Version.TryParse(currentVersion, out var current);

            if (canParseLatest && canParseCurrent && latest! > current!)
            {
                string? downloadUrl = null;
                string? installerName = null;
                string? sumsUrl = null;

                if (root.TryGetProperty("assets", out var assetsProp) && assetsProp.ValueKind == JsonValueKind.Array)
                {
                    (downloadUrl, installerName) = SelectServerAsset(assetsProp, PathService.IsPortable);
                    foreach (var asset in assetsProp.EnumerateArray())
                    {
                        var assetName = asset.TryGetProperty("name", out var nProp) ? nProp.GetString() : null;
                        if (assetName?.Equals("SHA256SUMS.txt", StringComparison.OrdinalIgnoreCase) == true)
                        {
                            sumsUrl = asset.TryGetProperty("browser_download_url", out var uProp) ? uProp.GetString() : null;
                            break;
                        }
                    }
                }

                return new UpdateInfo
                {
                    UpdateAvailable = true,
                    LatestVersion = latestVersion,
                    CurrentVersion = currentVersion,
                    DownloadUrl = downloadUrl,
                    InstallerName = installerName,
                    Sha256SumsUrl = sumsUrl,
                    ReleaseNotes = releaseBody
                };
            }

            return new UpdateInfo
            {
                UpdateAvailable = false,
                LatestVersion = latestVersion,
                CurrentVersion = currentVersion
            };
        }
        catch (Exception ex)
        {
            return new UpdateInfo
            {
                UpdateAvailable = false,
                CurrentVersion = APP_VERSION,
                Error = ex.Message
            };
        }
    }

    public static (string? url, string? name) SelectServerAsset(JsonElement assetsArray, bool isPortable = false)
    {
        if (assetsArray.ValueKind != JsonValueKind.Array)
            return (null, null);

        var items = new List<(string Name, string Url)>();
        foreach (var asset in assetsArray.EnumerateArray())
        {
            var name = asset.TryGetProperty("name", out var nProp) ? nProp.GetString() : null;
            var url = asset.TryGetProperty("browser_download_url", out var uProp) ? uProp.GetString() : null;
            if (!string.IsNullOrWhiteSpace(name) && !string.IsNullOrWhiteSpace(url))
            {
                items.Add((name, url));
            }
        }

        if (items.Count == 0)
            return (null, null);

        bool hasServerTaggedAssets = items.Any(a => a.Name.Contains("Server", StringComparison.OrdinalIgnoreCase));
        var archTag = System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture == System.Runtime.InteropServices.Architecture.Arm64
            ? "arm64"
            : "x64";

        if (isPortable)
        {
            var match = items.FirstOrDefault(a =>
                            a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase) &&
                            a.Name.Contains("Server", StringComparison.OrdinalIgnoreCase) &&
                            a.Name.Contains(archTag, StringComparison.OrdinalIgnoreCase))
                        is { Name: not null } m1 ? m1 :
                        items.FirstOrDefault(a =>
                            a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase) &&
                            a.Name.Contains("Server", StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrEmpty(match.Name))
                return (match.Url, match.Name);

            if (!hasServerTaggedAssets)
            {
                match = items.FirstOrDefault(a =>
                            a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase) &&
                            a.Name.Contains(archTag, StringComparison.OrdinalIgnoreCase))
                        is { Name: not null } m2 ? m2 :
                        items.FirstOrDefault(a => a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase));
                if (!string.IsNullOrEmpty(match.Name))
                    return (match.Url, match.Name);
            }
        }

        var selected = items.FirstOrDefault(a =>
            a.Name.Contains("Server", StringComparison.OrdinalIgnoreCase) &&
            a.Name.Contains("Setup", StringComparison.OrdinalIgnoreCase) &&
            a.Name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase));
        if (!string.IsNullOrEmpty(selected.Name))
            return (selected.Url, selected.Name);

        selected = items.FirstOrDefault(a =>
            a.Name.Contains("Server", StringComparison.OrdinalIgnoreCase) &&
            a.Name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase));
        if (!string.IsNullOrEmpty(selected.Name))
            return (selected.Url, selected.Name);

        selected = items.FirstOrDefault(a =>
            a.Name.Contains("Server", StringComparison.OrdinalIgnoreCase) &&
            a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase));
        if (!string.IsNullOrEmpty(selected.Name))
            return (selected.Url, selected.Name);

        if (!hasServerTaggedAssets)
        {
            selected = items.FirstOrDefault(a =>
                a.Name.Contains("Setup", StringComparison.OrdinalIgnoreCase) &&
                a.Name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrEmpty(selected.Name))
                return (selected.Url, selected.Name);

            selected = items.FirstOrDefault(a => a.Name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrEmpty(selected.Name))
                return (selected.Url, selected.Name);

            selected = items.FirstOrDefault(a => a.Name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase));
            if (!string.IsNullOrEmpty(selected.Name))
                return (selected.Url, selected.Name);
        }

        return (null, null);
    }

    public async Task<OperationResult> StartUpdateAsync(string downloadUrl, string installerName, string? sha256SumsUrl = null)
    {
        try
        {
            if (string.IsNullOrEmpty(downloadUrl) || string.IsNullOrEmpty(installerName))
                return new OperationResult { Success = false, Error = "Invalid download parameters" };

            if (!Uri.TryCreate(downloadUrl, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps)
                return new OperationResult { Success = false, Error = "HTTPS download URL required" };

            var allowedHosts = new[] { "github.com", "objects.githubusercontent.com", "github-releases.githubusercontent.com" };
            if (!allowedHosts.Any(h => uri.Host.Equals(h, StringComparison.OrdinalIgnoreCase) || uri.Host.EndsWith("." + h, StringComparison.OrdinalIgnoreCase)))
                return new OperationResult { Success = false, Error = $"Untrusted download host: {uri.Host}" };

            if (installerName.Contains("..") || installerName.Contains("/") || installerName.Contains("\\"))
                return new OperationResult { Success = false, Error = "Invalid installer name" };

            bool isExe = installerName.EndsWith(".exe", StringComparison.OrdinalIgnoreCase);
            bool isZip = installerName.EndsWith(".zip", StringComparison.OrdinalIgnoreCase);
            if (!isExe && !isZip)
                return new OperationResult { Success = false, Error = "Update package must be .exe or .zip" };

            if (string.IsNullOrEmpty(sha256SumsUrl))
                return new OperationResult { Success = false, Error = "Missing SHA256SUMS.txt verification URL (fail-closed)" };

            if (!Uri.TryCreate(sha256SumsUrl, UriKind.Absolute, out var sumsUri) || sumsUri.Scheme != Uri.UriSchemeHttps)
                return new OperationResult { Success = false, Error = "HTTPS SHA256SUMS URL required" };

            if (!allowedHosts.Any(h => sumsUri.Host.Equals(h, StringComparison.OrdinalIgnoreCase) || sumsUri.Host.EndsWith("." + h, StringComparison.OrdinalIgnoreCase)))
                return new OperationResult { Success = false, Error = $"Untrusted SHA256SUMS host: {sumsUri.Host}" };

            using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(3) };
            client.DefaultRequestHeaders.Add("User-Agent", "USBAnywhere-Server");

            var tempDir = Path.Combine(Path.GetTempPath(), $"USBAnywhereSrv_Upd_{Guid.NewGuid():N}");
            Directory.CreateDirectory(tempDir);
            var packagePath = Path.Combine(tempDir, installerName);

            var data = await client.GetByteArrayAsync(downloadUrl);
            await File.WriteAllBytesAsync(packagePath, data);

            // Mandatory Fail-Closed SHA-256 Verification
            var sumsContent = await client.GetStringAsync(sha256SumsUrl);
            var expectedHash = ExtractHashForFile(sumsContent, installerName);
            if (string.IsNullOrEmpty(expectedHash))
            {
                try { File.Delete(packagePath); } catch { }
                return new OperationResult { Success = false, Error = $"Hash for {installerName} not found in SHA256SUMS.txt" };
            }

            var actualHash = ComputeSha256(packagePath);
            if (!string.Equals(actualHash, expectedHash, StringComparison.OrdinalIgnoreCase))
            {
                try { File.Delete(packagePath); } catch { }
                return new OperationResult
                {
                    Success = false,
                    Error = $"SHA-256 mismatch!\nExpected: {expectedHash}\nActual: {actualHash}"
                };
            }

            if (isExe)
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = packagePath,
                    UseShellExecute = true,
                    Verb = "runas"
                });
                System.Windows.Application.Current.Shutdown();
                return new OperationResult { Success = true };
            }
            else
            {
                // Portable ZIP update
                var extractDir = Path.Combine(tempDir, $"USBAnywhereServer_Update_{Guid.NewGuid():N}");
                ZipFile.ExtractToDirectory(packagePath, extractDir, overwriteFiles: true);
                var appDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
                var exePath = Environment.ProcessPath ?? Path.Combine(appDir, "USBAnywhere-Server.exe");
                var pid = Environment.ProcessId;

                var batchPath = Path.Combine(tempDir, $"usbanywhere_server_upd_{pid}.cmd");
                var batchContent = $@"@echo off
timeout /t 2 /nobreak >nul
xcopy /s /e /y ""{extractDir}\*"" ""{appDir}\"" >nul
start """" ""{exePath}""
rd /s /q ""{extractDir}""
del ""{packagePath}""
del ""%~f0""
";
                await File.WriteAllTextAsync(batchPath, batchContent);
                Process.Start(new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = $"/c \"{batchPath}\"",
                    CreateNoWindow = true,
                    UseShellExecute = false
                });
                System.Windows.Application.Current.Shutdown();
                return new OperationResult { Success = true };
            }
        }
        catch (Exception ex)
        {
            return new OperationResult { Success = false, Error = ex.Message };
        }
    }

    private static string? ExtractHashForFile(string sumsContent, string fileName)
    {
        var lines = sumsContent.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        foreach (var line in lines)
        {
            var parts = line.Trim().Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length >= 2 && parts[1].TrimStart('*').Equals(fileName, StringComparison.OrdinalIgnoreCase))
            {
                return parts[0].Trim();
            }
        }
        return null;
    }

    private static string ComputeSha256(string filePath)
    {
        using var sha256 = SHA256.Create();
        using var stream = File.OpenRead(filePath);
        var bytes = sha256.ComputeHash(stream);
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}

public class UpdateInfo
{
    public bool UpdateAvailable { get; set; }
    public string LatestVersion { get; set; } = "";
    public string CurrentVersion { get; set; } = "";
    public string? DownloadUrl { get; set; }
    public string? InstallerName { get; set; }
    public string? Sha256SumsUrl { get; set; }
    public string? ReleaseNotes { get; set; }
    public string? Error { get; set; }
}

public class OperationResult
{
    public bool Success { get; set; }
    public string? Error { get; set; }
}

public class GitHubRelease
{
    [System.Text.Json.Serialization.JsonPropertyName("tag_name")]
    public string? TagName { get; set; }

    [System.Text.Json.Serialization.JsonPropertyName("body")]
    public string? Body { get; set; }

    [System.Text.Json.Serialization.JsonPropertyName("assets")]
    public List<GitHubAsset>? Assets { get; set; }
}

public class GitHubAsset
{
    [System.Text.Json.Serialization.JsonPropertyName("name")]
    public string? Name { get; set; }

    [System.Text.Json.Serialization.JsonPropertyName("browser_download_url")]
    public string? BrowserDownloadUrl { get; set; }
}
