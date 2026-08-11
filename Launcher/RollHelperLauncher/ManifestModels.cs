using System.Text.Json;
using System.Text.Json.Serialization;

namespace RollHelperLauncher;

internal static class JsonOptions
{
    public static JsonSerializerOptions Default { get; } = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };
}

internal sealed class ReleaseManifest
{
    public int Schema { get; init; } = 1;
    public string? Release { get; init; }
    public List<ReleasePackage> Packages { get; init; } = [];
}

internal sealed class ReleasePackage
{
    public required string Id { get; init; }
    public required string Version { get; init; }
    public string? DisplayName { get; init; }
    public string? Type { get; init; }
    public string? Url { get; init; }
    public string? Asset { get; init; }
    public string? Sha256 { get; init; }
    public long? Size { get; init; }

    [JsonIgnore]
    public Uri? DownloadUri { get; set; }

    public override string ToString() => DisplayName ?? Id;
}

internal sealed class PackageManifest
{
    public int Schema { get; init; } = 1;
    public required string Id { get; init; }
    public required string Version { get; init; }
    public string? DisplayName { get; init; }
    public required PackageEntrypoint Entrypoint { get; init; }
}

internal sealed class PackageEntrypoint
{
    public required string File { get; init; }
    public string? Arguments { get; init; }
    public string? WorkingDirectory { get; init; }
}
