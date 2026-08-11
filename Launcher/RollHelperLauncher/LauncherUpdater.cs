using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;

namespace RollHelperLauncher;

internal sealed class LauncherUpdater
{
    private const string ExecutableName = "RollHelperLauncher.exe";
    private readonly ManifestClient _manifestClient;

    public LauncherUpdater(ManifestClient manifestClient)
    {
        _manifestClient = manifestClient;
    }

    public string CurrentVersion => GetCurrentVersion();

    public bool IsUpdateAvailable(LauncherRelease? release)
    {
        return release is not null
            && TryParseVersion(release.Version, out var availableVersion)
            && TryParseVersion(CurrentVersion, out var currentVersion)
            && availableVersion > currentVersion;
    }

    public async Task PrepareAndRestartAsync(
        LauncherRelease release,
        IProgress<int>? progress,
        CancellationToken cancellationToken)
    {
        if (release.DownloadUri is null)
        {
            throw new InvalidOperationException("Launcher update has no resolved download URL.");
        }

        var updateId = $"launcher-{LauncherPaths.SafePathSegment(release.Version)}-{Guid.NewGuid():N}";
        var archivePath = Path.Combine(LauncherPaths.CacheDirectory, updateId + ".zip");
        var stagingDirectory = Path.Combine(LauncherPaths.CacheDirectory, updateId);

        try
        {
            LauncherLog.Info($"Preparing launcher update {CurrentVersion} -> {release.Version}");
            await _manifestClient.DownloadFileAsync(release.DownloadUri, archivePath, progress, cancellationToken);
            await VerifySha256Async(archivePath, release.Sha256, cancellationToken);

            Directory.CreateDirectory(stagingDirectory);
            ExtractZipSafely(archivePath, stagingDirectory);

            var stagedExecutable = Path.Combine(stagingDirectory, ExecutableName);
            if (!File.Exists(stagedExecutable))
            {
                throw new InvalidDataException($"Launcher archive does not contain {ExecutableName}.");
            }

            EnsureTargetIsWritable();
            var updaterScript = WriteUpdaterScript();
            StartUpdater(updaterScript, stagingDirectory, archivePath);
            LauncherLog.Info("Launcher updater started; closing current process");
        }
        catch
        {
            TryDeleteFile(archivePath);
            TryDeleteDirectory(stagingDirectory);
            throw;
        }
    }

    private static string GetCurrentVersion()
    {
        var informationalVersion = Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
            .InformationalVersion
            .Split('+')[0];

        return string.IsNullOrWhiteSpace(informationalVersion)
            ? Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "0.0.0"
            : informationalVersion;
    }

    private static bool TryParseVersion(string value, out Version version)
    {
        return Version.TryParse(value.Trim().TrimStart('v', 'V'), out version!);
    }

    private static async Task VerifySha256Async(
        string filePath,
        string expectedHash,
        CancellationToken cancellationToken)
    {
        LauncherLog.Info("Verifying launcher update SHA-256");
        await using var stream = File.OpenRead(filePath);
        var actualHash = Convert.ToHexString(await SHA256.HashDataAsync(stream, cancellationToken));
        var normalizedExpected = expectedHash.Replace("-", string.Empty).Trim();

        if (!string.Equals(actualHash, normalizedExpected, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidDataException(
                $"Launcher SHA-256 mismatch. Expected={normalizedExpected}, actual={actualHash}");
        }
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
                throw new InvalidDataException($"Unsafe launcher ZIP entry: {entry.FullName}");
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

    private static void EnsureTargetIsWritable()
    {
        var probePath = Path.Combine(AppContext.BaseDirectory, $".rollhelper-write-{Guid.NewGuid():N}.tmp");
        try
        {
            File.WriteAllText(probePath, "ok");
        }
        finally
        {
            TryDeleteFile(probePath);
        }
    }

    private static string WriteUpdaterScript()
    {
        var scriptPath = Path.Combine(
            LauncherPaths.CacheDirectory,
            $"apply-launcher-update-{Guid.NewGuid():N}.ps1");
        var logPath = Path.Combine(LauncherPaths.LogsDirectory, "updater.log");
        var script = """
            param(
                [int]$LauncherProcessId,
                [string]$SourceDirectory,
                [string]$TargetDirectory,
                [string]$ArchivePath,
                [string]$LogPath
            )

            $ErrorActionPreference = 'Stop'

            function Write-UpdateLog([string]$Message) {
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') $Message" -Encoding UTF8
            }

            try {
                Write-UpdateLog "Waiting for launcher PID $LauncherProcessId"
                for ($attempt = 0; $attempt -lt 120; $attempt++) {
                    if (-not (Get-Process -Id $LauncherProcessId -ErrorAction SilentlyContinue)) { break }
                    Start-Sleep -Milliseconds 500
                }

                if (Get-Process -Id $LauncherProcessId -ErrorAction SilentlyContinue) {
                    throw 'Launcher did not close within 60 seconds.'
                }

                Start-Sleep -Milliseconds 300
                Write-UpdateLog "Copying update to $TargetDirectory"
                Get-ChildItem -LiteralPath $SourceDirectory -Force | ForEach-Object {
                    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $TargetDirectory $_.Name) -Recurse -Force
                }

                $executable = Join-Path $TargetDirectory 'RollHelperLauncher.exe'
                Write-UpdateLog "Starting $executable"
                Start-Process -FilePath $executable -WorkingDirectory $TargetDirectory
            }
            catch {
                Write-UpdateLog "ERROR: $($_.Exception.Message)"
                Add-Type -AssemblyName PresentationFramework
                [System.Windows.MessageBox]::Show(
                    "Не удалось обновить RollHelper Launcher.`n`n$($_.Exception.Message)`n`nЛог: $LogPath",
                    'RollHelper Launcher',
                    'OK',
                    'Error') | Out-Null
            }
            finally {
                Start-Sleep -Milliseconds 500
                Remove-Item -LiteralPath $SourceDirectory -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $ArchivePath -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
            }
            """;

        File.WriteAllText(scriptPath, script, new UTF8Encoding(encoderShouldEmitUTF8Identifier: true));
        return scriptPath;
    }

    private static void StartUpdater(string scriptPath, string stagingDirectory, string archivePath)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            UseShellExecute = false,
            CreateNoWindow = true
        };
        startInfo.ArgumentList.Add("-NoLogo");
        startInfo.ArgumentList.Add("-NoProfile");
        startInfo.ArgumentList.Add("-NonInteractive");
        startInfo.ArgumentList.Add("-WindowStyle");
        startInfo.ArgumentList.Add("Hidden");
        startInfo.ArgumentList.Add("-ExecutionPolicy");
        startInfo.ArgumentList.Add("Bypass");
        startInfo.ArgumentList.Add("-File");
        startInfo.ArgumentList.Add(scriptPath);
        startInfo.ArgumentList.Add("-LauncherProcessId");
        startInfo.ArgumentList.Add(Environment.ProcessId.ToString());
        startInfo.ArgumentList.Add("-SourceDirectory");
        startInfo.ArgumentList.Add(stagingDirectory);
        startInfo.ArgumentList.Add("-TargetDirectory");
        startInfo.ArgumentList.Add(AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar));
        startInfo.ArgumentList.Add("-ArchivePath");
        startInfo.ArgumentList.Add(archivePath);
        startInfo.ArgumentList.Add("-LogPath");
        startInfo.ArgumentList.Add(Path.Combine(LauncherPaths.LogsDirectory, "updater.log"));

        _ = Process.Start(startInfo)
            ?? throw new InvalidOperationException("Windows did not start the launcher updater.");
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
        catch
        {
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
        catch
        {
        }
    }
}
