using System.IO.Compression;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using RollHelperLauncher;

var testRoot = Path.Combine(Path.GetTempPath(), $"RollHelperPackageRepair-{Guid.NewGuid():N}");
var programRoot = Path.Combine(testRoot, "program");
var userRoot = Path.Combine(testRoot, "user");
var sourceRoot = Path.Combine(testRoot, "source");
var packageZip = Path.Combine(testRoot, "test-module.zip");

Directory.CreateDirectory(sourceRoot);
Environment.SetEnvironmentVariable("ROLLHELPER_PROGRAM_ROOT", programRoot);
Environment.SetEnvironmentVariable("ROLLHELPER_USER_ROOT", userRoot);

try
{
    await File.WriteAllTextAsync(
        Path.Combine(sourceRoot, "package.json"),
        """
        {
          "schema": 1,
          "id": "test-module",
          "version": "1.0.0",
          "displayName": "Test Module"
        }
        """);
    await File.WriteAllTextAsync(Path.Combine(sourceRoot, "payload.txt"), "ok");
    ZipFile.CreateFromDirectory(sourceRoot, packageZip);

    var packageBytes = await File.ReadAllBytesAsync(packageZip);
    var listener = new TcpListener(IPAddress.Loopback, 0);
    listener.Start();
    var port = ((IPEndPoint)listener.LocalEndpoint).Port;
    var serverTask = ServeOnceAsync(listener, packageBytes);

    var package = new ReleasePackage
    {
        Id = "test-module",
        Version = "1.0.0",
        DisplayName = "Test Module",
        Type = "module",
        Extends = "test-brand",
        Url = $"http://127.0.0.1:{port}/test-module.zip",
        Sha256 = Convert.ToHexString(SHA256.HashData(packageBytes)).ToLowerInvariant(),
        DownloadUri = new Uri($"http://127.0.0.1:{port}/test-module.zip")
    };

    LauncherPaths.EnsureDirectories();
    var stateStore = new PackageStateStore();
    stateStore.MarkInstalled(package.Id, package.Version, enabled: false);

    var incompleteDirectory = LauncherPaths.GetPackageVersionDirectory(package.Id, package.Version);
    Directory.CreateDirectory(incompleteDirectory);
    await File.WriteAllTextAsync(Path.Combine(incompleteDirectory, "orphan.txt"), "stale");

    using var manifestClient = new ManifestClient();
    var installer = new PackageInstaller(manifestClient, stateStore);
    await installer.InstallAsync(package, progress: null, CancellationToken.None);
    installer.SetEnabled(package, true);
    await serverTask;

    if (!installer.IsInstalled(package) || !installer.IsEnabled(package))
    {
        throw new InvalidOperationException("Incomplete module package was not repaired and enabled.");
    }

    stateStore.Remove(package.Id);
    if (!installer.IsInstalled(package) || installer.IsEnabled(package))
    {
        throw new InvalidOperationException("Missing-state scenario was not created correctly.");
    }

    await installer.InstallAsync(package, progress: null, CancellationToken.None);
    installer.SetEnabled(package, true);
    if (!installer.IsEnabled(package)
        || !string.Equals(stateStore.Get(package.Id)?.Version, package.Version, StringComparison.OrdinalIgnoreCase))
    {
        throw new InvalidOperationException("Installed module files did not rebuild missing package state.");
    }

    Console.WriteLine("Package repair test passed.");
}
finally
{
    try
    {
        Directory.Delete(testRoot, recursive: true);
    }
    catch
    {
    }
}

static async Task ServeOnceAsync(TcpListener listener, byte[] payload)
{
    try
    {
        using var client = await listener.AcceptTcpClientAsync();
        await using var stream = client.GetStream();
        using var reader = new StreamReader(stream, leaveOpen: true);
        while (!string.IsNullOrEmpty(await reader.ReadLineAsync()))
        {
        }

        var headers = System.Text.Encoding.ASCII.GetBytes(
            $"HTTP/1.1 200 OK\r\nContent-Length: {payload.Length}\r\nConnection: close\r\n\r\n");
        await stream.WriteAsync(headers);
        await stream.WriteAsync(payload);
    }
    finally
    {
        listener.Stop();
    }
}
