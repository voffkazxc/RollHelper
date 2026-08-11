namespace RollHelperLauncher;

internal static class PackageVersion
{
    public static bool TryParse(string value, out Version version)
    {
        var normalized = value.Trim().Split('-', '+')[0];
        return Version.TryParse(normalized, out version!);
    }

    public static bool IsAtLeast(string installedVersion, string minimumVersion)
    {
        return TryParse(installedVersion, out var installed)
            && TryParse(minimumVersion, out var minimum)
            && installed >= minimum;
    }
}
