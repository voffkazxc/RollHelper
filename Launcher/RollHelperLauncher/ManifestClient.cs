using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;

namespace RollHelperLauncher;

internal sealed class ManifestClient : IDisposable
{
    private readonly HttpClient _httpClient;

    public ManifestClient()
    {
        _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromMinutes(5)
        };
        _httpClient.DefaultRequestHeaders.UserAgent.Add(
            new ProductInfoHeaderValue("RollHelperLauncher", "1.0"));
    }

    public async Task<ReleaseManifest> DownloadManifestAsync(Uri manifestUri, CancellationToken cancellationToken)
    {
        LauncherLog.Info($"Downloading release manifest: {manifestUri}");

        using var response = await _httpClient.GetAsync(manifestUri, cancellationToken);
        response.EnsureSuccessStatusCode();

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        var manifest = await JsonSerializer.DeserializeAsync<ReleaseManifest>(stream, JsonOptions.Default, cancellationToken)
            ?? throw new InvalidDataException("release-manifest.json is empty.");

        if (manifest.Schema != 1)
        {
            throw new InvalidDataException($"Unsupported release manifest schema: {manifest.Schema}");
        }

        foreach (var package in manifest.Packages)
        {
            ValidatePackage(package);
            package.DownloadUri = ResolvePackageUri(manifestUri, package);
        }

        if (manifest.Launcher is not null)
        {
            ValidateLauncher(manifest.Launcher);
            manifest.Launcher.DownloadUri = ResolveAssetUri(
                manifestUri,
                manifest.Launcher.Url,
                manifest.Launcher.Asset);
        }

        LauncherLog.Info($"Manifest loaded. Release={manifest.Release ?? "unknown"}, packages={manifest.Packages.Count}");
        return manifest;
    }

    public async Task DownloadFileAsync(
        Uri source,
        string destination,
        IProgress<int>? progress,
        CancellationToken cancellationToken)
    {
        LauncherLog.Info($"Downloading package: {source}");
        LauncherLog.Info($"Download destination: {destination}");

        using var response = await _httpClient.GetAsync(source, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();

        var totalLength = response.Content.Headers.ContentLength;
        await using var sourceStream = await response.Content.ReadAsStreamAsync(cancellationToken);
        await using var destinationStream = new FileStream(
            destination,
            FileMode.Create,
            FileAccess.Write,
            FileShare.None,
            81920,
            useAsync: true);

        var buffer = new byte[81920];
        long totalRead = 0;

        while (true)
        {
            var read = await sourceStream.ReadAsync(buffer, cancellationToken);
            if (read == 0)
            {
                break;
            }

            await destinationStream.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            totalRead += read;

            if (totalLength is > 0)
            {
                progress?.Report((int)Math.Clamp(totalRead * 100 / totalLength.Value, 0, 100));
            }
        }

        progress?.Report(100);
        LauncherLog.Info($"Package downloaded. Bytes={totalRead}");
    }

    private static void ValidatePackage(ReleasePackage package)
    {
        LauncherPaths.SafePathSegment(package.Id);
        LauncherPaths.SafePathSegment(package.Version);

        var packageType = package.Type?.Trim().ToLowerInvariant();
        if (packageType == "module")
        {
            if (string.IsNullOrWhiteSpace(package.Extends))
            {
                throw new InvalidDataException($"Module {package.Id} has no extends package id.");
            }

            LauncherPaths.SafePathSegment(package.Extends);
        }

        foreach (var requirement in package.Requires)
        {
            LauncherPaths.SafePathSegment(requirement.Id);
            if (!string.IsNullOrWhiteSpace(requirement.MinVersion)
                && !PackageVersion.TryParse(requirement.MinVersion, out _))
            {
                throw new InvalidDataException(
                    $"Package {package.Id} has invalid minimum version {requirement.MinVersion} for {requirement.Id}.");
            }
        }

        if (string.IsNullOrWhiteSpace(package.Url) && string.IsNullOrWhiteSpace(package.Asset))
        {
            throw new InvalidDataException($"Package {package.Id} has neither url nor asset.");
        }
    }

    private static void ValidateLauncher(LauncherRelease launcher)
    {
        LauncherPaths.SafePathSegment(launcher.Version);

        if (string.IsNullOrWhiteSpace(launcher.Url) && string.IsNullOrWhiteSpace(launcher.Asset))
        {
            throw new InvalidDataException("Launcher update has neither url nor asset.");
        }

        if (string.IsNullOrWhiteSpace(launcher.Sha256))
        {
            throw new InvalidDataException("Launcher update has no SHA-256 checksum.");
        }
    }

    private static Uri ResolvePackageUri(Uri manifestUri, ReleasePackage package)
    {
        return ResolveAssetUri(manifestUri, package.Url, package.Asset);
    }

    private static Uri ResolveAssetUri(Uri manifestUri, string? url, string? asset)
    {
        var location = !string.IsNullOrWhiteSpace(url) ? url : asset;
        if (Uri.TryCreate(location, UriKind.Absolute, out var absoluteUri))
        {
            return absoluteUri;
        }

        return new Uri(manifestUri, location);
    }

    public void Dispose() => _httpClient.Dispose();
}
