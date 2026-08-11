using System.Text.Json;

namespace RollHelperLauncher;

internal sealed class LauncherConfig
{
    private const string DefaultManifestUrl =
        "https://github.com/voffkazxc/RollHelper/releases/latest/download/release-manifest.json";

    public string ManifestUrl { get; init; } = DefaultManifestUrl;

    public static LauncherConfig Load()
    {
        if (!File.Exists(LauncherPaths.ConfigFile))
        {
            LauncherLog.Info($"Config file not found. Using default manifest URL: {DefaultManifestUrl}");
            return new LauncherConfig();
        }

        LauncherLog.Info($"Loading config: {LauncherPaths.ConfigFile}");
        var json = File.ReadAllText(LauncherPaths.ConfigFile);
        var config = JsonSerializer.Deserialize<LauncherConfig>(json, JsonOptions.Default)
            ?? throw new InvalidDataException("launcher.config.json is empty or invalid.");

        if (!Uri.TryCreate(config.ManifestUrl, UriKind.Absolute, out var manifestUri)
            || (manifestUri.Scheme != Uri.UriSchemeHttps && manifestUri.Scheme != Uri.UriSchemeHttp))
        {
            throw new InvalidDataException("ManifestUrl must be an absolute HTTP or HTTPS URL.");
        }

        return config;
    }
}
