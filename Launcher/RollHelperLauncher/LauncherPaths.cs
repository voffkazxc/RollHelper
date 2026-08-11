namespace RollHelperLauncher;

internal static class LauncherPaths
{
    public static string ProgramRoot { get; } = ResolveRoot(
        "ROLLHELPER_PROGRAM_ROOT",
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs",
            "RollHelper"));

    public static string UserRoot { get; } = ResolveRoot(
        "ROLLHELPER_USER_ROOT",
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "RollHelper"));

    public static string PackagesDirectory { get; } = Path.Combine(ProgramRoot, "Packages");
    public static string CacheDirectory { get; } = Path.Combine(ProgramRoot, "Cache");
    public static string StateDirectory { get; } = Path.Combine(ProgramRoot, "State");
    public static string LogsDirectory { get; } = Path.Combine(UserRoot, "Logs");
    public static string LogFile { get; } = Path.Combine(LogsDirectory, "launcher.log");
    public static string ConfigFile { get; } = Path.Combine(AppContext.BaseDirectory, "launcher.config.json");
    public static string PackageStateFile { get; } = Path.Combine(StateDirectory, "packages.json");
    public static string LauncherUiStateFile { get; } = Path.Combine(StateDirectory, "launcher-ui.json");

    public static void EnsureDirectories()
    {
        Directory.CreateDirectory(ProgramRoot);
        Directory.CreateDirectory(UserRoot);
        Directory.CreateDirectory(PackagesDirectory);
        Directory.CreateDirectory(CacheDirectory);
        Directory.CreateDirectory(StateDirectory);
        Directory.CreateDirectory(LogsDirectory);
    }

    public static string GetPackageVersionDirectory(string packageId, string version)
    {
        return Path.Combine(
            PackagesDirectory,
            SafePathSegment(packageId),
            SafePathSegment(version));
    }

    public static string SafePathSegment(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidDataException("Package id or version is empty.");
        }

        var invalidCharacters = Path.GetInvalidFileNameChars();
        if (value is "." or ".." || value.IndexOfAny(invalidCharacters) >= 0 || value.Contains('/') || value.Contains('\\'))
        {
            throw new InvalidDataException($"Unsafe package path segment: {value}");
        }

        return value;
    }

    private static string ResolveRoot(string environmentVariable, string fallback)
    {
        var configured = Environment.GetEnvironmentVariable(environmentVariable);
        return Path.GetFullPath(string.IsNullOrWhiteSpace(configured) ? fallback : configured);
    }
}
