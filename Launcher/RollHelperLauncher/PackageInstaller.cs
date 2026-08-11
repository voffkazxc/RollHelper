using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;

namespace RollHelperLauncher;

internal sealed class PackageInstaller
{
    private readonly ManifestClient _manifestClient;

    public PackageInstaller(ManifestClient manifestClient)
    {
        _manifestClient = manifestClient;
    }

    public bool IsInstalled(ReleasePackage package)
    {
        var installDirectory = LauncherPaths.GetPackageVersionDirectory(package.Id, package.Version);
        return File.Exists(Path.Combine(installDirectory, "package.json"));
    }

    public bool HasInstalledVersion(string packageId)
    {
        var packageDirectory = Path.Combine(
            LauncherPaths.PackagesDirectory,
            LauncherPaths.SafePathSegment(packageId));

        return Directory.Exists(packageDirectory)
            && Directory.EnumerateFiles(packageDirectory, "package.json", SearchOption.AllDirectories).Any();
    }

    public async Task<string> InstallAsync(
        ReleasePackage package,
        IProgress<int>? progress,
        CancellationToken cancellationToken)
    {
        if (package.DownloadUri is null)
        {
            throw new InvalidOperationException($"Package {package.Id} has no resolved download URL.");
        }

        var installDirectory = LauncherPaths.GetPackageVersionDirectory(package.Id, package.Version);
        if (IsInstalled(package))
        {
            LauncherLog.Info($"Package already installed: {package.Id} {package.Version}");
            return installDirectory;
        }

        var cacheFile = Path.Combine(
            LauncherPaths.CacheDirectory,
            $"{LauncherPaths.SafePathSegment(package.Id)}-{LauncherPaths.SafePathSegment(package.Version)}-{Guid.NewGuid():N}.zip");
        var stagingDirectory = installDirectory + $".staging-{Guid.NewGuid():N}";

        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(installDirectory)!);
            await _manifestClient.DownloadFileAsync(package.DownloadUri, cacheFile, progress, cancellationToken);

            if (!string.IsNullOrWhiteSpace(package.Sha256))
            {
                await VerifySha256Async(cacheFile, package.Sha256, cancellationToken);
            }

            LauncherLog.Info($"Extracting package to staging directory: {stagingDirectory}");
            Directory.CreateDirectory(stagingDirectory);
            ExtractZipSafely(cacheFile, stagingDirectory);

            var packageManifest = LoadPackageManifest(stagingDirectory);
            ValidatePackageIdentity(package, packageManifest);
            ValidateEntrypoint(stagingDirectory, packageManifest.Entrypoint);

            if (Directory.Exists(installDirectory))
            {
                throw new IOException($"Install directory already exists but package is incomplete: {installDirectory}");
            }

            Directory.Move(stagingDirectory, installDirectory);
            LauncherLog.Info($"Package installed: {package.Id} {package.Version} -> {installDirectory}");
            return installDirectory;
        }
        catch (Exception exception)
        {
            LauncherLog.Error($"Package installation failed: {package.Id} {package.Version}", exception);
            throw;
        }
        finally
        {
            TryDeleteFile(cacheFile);
            TryDeleteDirectory(stagingDirectory);
        }
    }

    public Process Launch(ReleasePackage package)
    {
        var installDirectory = LauncherPaths.GetPackageVersionDirectory(package.Id, package.Version);
        var packageManifest = LoadPackageManifest(installDirectory);
        ValidatePackageIdentity(package, packageManifest);

        var entrypointPath = ResolveInsideDirectory(installDirectory, packageManifest.Entrypoint.File);
        var workingDirectory = string.IsNullOrWhiteSpace(packageManifest.Entrypoint.WorkingDirectory)
            ? Path.GetDirectoryName(entrypointPath)!
            : ResolveInsideDirectory(installDirectory, packageManifest.Entrypoint.WorkingDirectory);

        LauncherLog.Info($"Launching package: {package.Id} {package.Version}");
        LauncherLog.Info($"Entrypoint: {entrypointPath}");
        LauncherLog.Info($"Working directory: {workingDirectory}");

        var startInfo = new ProcessStartInfo
        {
            FileName = entrypointPath,
            Arguments = packageManifest.Entrypoint.Arguments ?? string.Empty,
            WorkingDirectory = workingDirectory,
            UseShellExecute = true
        };

        var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException($"Windows did not start entrypoint: {entrypointPath}");

        LauncherLog.Info($"Package process started. PID={process.Id}");
        return process;
    }

    private static PackageManifest LoadPackageManifest(string packageDirectory)
    {
        var manifestPath = Path.Combine(packageDirectory, "package.json");
        if (!File.Exists(manifestPath))
        {
            throw new InvalidDataException($"package.json not found in package root: {packageDirectory}");
        }

        var manifest = JsonSerializer.Deserialize<PackageManifest>(File.ReadAllText(manifestPath), JsonOptions.Default)
            ?? throw new InvalidDataException($"Invalid package manifest: {manifestPath}");

        if (manifest.Schema != 1)
        {
            throw new InvalidDataException($"Unsupported package schema: {manifest.Schema}");
        }

        return manifest;
    }

    private static void ValidatePackageIdentity(ReleasePackage releasePackage, PackageManifest packageManifest)
    {
        if (!string.Equals(releasePackage.Id, packageManifest.Id, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException(
                $"Package id mismatch. Release={releasePackage.Id}, zip={packageManifest.Id}");
        }

        if (!string.Equals(releasePackage.Version, packageManifest.Version, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException(
                $"Package version mismatch. Release={releasePackage.Version}, zip={packageManifest.Version}");
        }
    }

    private static void ValidateEntrypoint(string packageDirectory, PackageEntrypoint entrypoint)
    {
        var entrypointPath = ResolveInsideDirectory(packageDirectory, entrypoint.File);
        if (!File.Exists(entrypointPath))
        {
            throw new InvalidDataException($"Package entrypoint not found: {entrypoint.File}");
        }

        if (!string.IsNullOrWhiteSpace(entrypoint.WorkingDirectory))
        {
            var workingDirectory = ResolveInsideDirectory(packageDirectory, entrypoint.WorkingDirectory);
            if (!Directory.Exists(workingDirectory))
            {
                throw new InvalidDataException($"Package working directory not found: {entrypoint.WorkingDirectory}");
            }
        }
    }

    private static async Task VerifySha256Async(string filePath, string expectedHash, CancellationToken cancellationToken)
    {
        LauncherLog.Info("Verifying package SHA-256");
        await using var stream = File.OpenRead(filePath);
        var actualHash = Convert.ToHexString(await SHA256.HashDataAsync(stream, cancellationToken));
        var normalizedExpected = expectedHash.Replace("-", string.Empty).Trim();

        if (!string.Equals(actualHash, normalizedExpected, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException($"SHA-256 mismatch. Expected={normalizedExpected}, actual={actualHash}");
        }

        LauncherLog.Info("Package SHA-256 is valid");
    }

    private static void ExtractZipSafely(string zipFile, string destinationDirectory)
    {
        var destinationRoot = Path.GetFullPath(destinationDirectory)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
            + Path.DirectorySeparatorChar;

        using var archive = ZipFile.OpenRead(zipFile);
        foreach (var entry in archive.Entries)
        {
            var destinationPath = Path.GetFullPath(Path.Combine(destinationRoot, entry.FullName));
            if (!destinationPath.StartsWith(destinationRoot, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException($"Unsafe ZIP entry: {entry.FullName}");
            }

            if (string.IsNullOrEmpty(entry.Name))
            {
                Directory.CreateDirectory(destinationPath);
                continue;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
            entry.ExtractToFile(destinationPath, overwrite: false);
        }
    }

    private static string ResolveInsideDirectory(string rootDirectory, string relativePath)
    {
        if (Path.IsPathRooted(relativePath))
        {
            throw new InvalidDataException($"Absolute package path is not allowed: {relativePath}");
        }

        var root = Path.GetFullPath(rootDirectory)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var rootPrefix = root + Path.DirectorySeparatorChar;
        var resolved = Path.GetFullPath(Path.Combine(root, relativePath));

        if (!string.Equals(resolved, root, StringComparison.OrdinalIgnoreCase)
            && !resolved.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException($"Package path escapes installation directory: {relativePath}");
        }

        return resolved;
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (Exception exception)
        {
            LauncherLog.Warning($"Could not delete cache file {path}: {exception.Message}");
        }
    }

    private static void TryDeleteDirectory(string path)
    {
        try
        {
            if (Directory.Exists(path))
            {
                Directory.Delete(path, recursive: true);
            }
        }
        catch (Exception exception)
        {
            LauncherLog.Warning($"Could not delete staging directory {path}: {exception.Message}");
        }
    }
}
