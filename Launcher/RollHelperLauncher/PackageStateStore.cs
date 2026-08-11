using System.Text.Json;

namespace RollHelperLauncher;

internal sealed class PackageStateStore
{
    private readonly string _stateFile;
    private readonly object _sync = new();
    private PackageStateDocument _document;

    public PackageStateStore(string? stateFile = null)
    {
        _stateFile = stateFile ?? LauncherPaths.PackageStateFile;
        _document = Load();
    }

    public PackageStateEntry? Get(string packageId)
    {
        lock (_sync)
        {
            return _document.Packages.TryGetValue(packageId, out var state)
                ? state with { }
                : null;
        }
    }

    public bool IsEnabled(string packageId) => Get(packageId)?.Enabled ?? false;

    public void MarkInstalled(string packageId, string version, bool enabled = true)
    {
        lock (_sync)
        {
            _document.Packages[packageId] = new PackageStateEntry(version, enabled);
            Save();
        }
    }

    public void SetEnabled(string packageId, bool enabled)
    {
        lock (_sync)
        {
            if (!_document.Packages.TryGetValue(packageId, out var current))
            {
                throw new InvalidOperationException($"Package {packageId} is not installed.");
            }

            _document.Packages[packageId] = current with { Enabled = enabled };
            Save();
        }
    }

    public void Remove(string packageId)
    {
        lock (_sync)
        {
            if (_document.Packages.Remove(packageId))
            {
                Save();
            }
        }
    }

    private PackageStateDocument Load()
    {
        try
        {
            if (!File.Exists(_stateFile))
            {
                return new PackageStateDocument();
            }

            var loaded = JsonSerializer.Deserialize<PackageStateDocument>(File.ReadAllText(_stateFile), JsonOptions.Default)
                ?? new PackageStateDocument();
            return new PackageStateDocument
            {
                Packages = new Dictionary<string, PackageStateEntry>(
                    loaded.Packages,
                    StringComparer.OrdinalIgnoreCase)
            };
        }
        catch (Exception exception)
        {
            LauncherLog.Warning($"Could not read package state. Starting with empty state: {exception.Message}");
            return new PackageStateDocument();
        }
    }

    private void Save()
    {
        var directory = Path.GetDirectoryName(_stateFile)!;
        Directory.CreateDirectory(directory);
        var temporaryFile = _stateFile + $".tmp-{Guid.NewGuid():N}";

        try
        {
            File.WriteAllText(temporaryFile, JsonSerializer.Serialize(_document, JsonOptions.Default));
            File.Move(temporaryFile, _stateFile, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporaryFile))
            {
                File.Delete(temporaryFile);
            }
        }
    }

    private sealed class PackageStateDocument
    {
        public int Schema { get; init; } = 1;
        public Dictionary<string, PackageStateEntry> Packages { get; init; }
            = new(StringComparer.OrdinalIgnoreCase);
    }
}

internal sealed record PackageStateEntry(string Version, bool Enabled);
