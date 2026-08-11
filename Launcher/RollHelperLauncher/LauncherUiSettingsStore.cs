using System.Text.Json;

namespace RollHelperLauncher;

internal sealed class LauncherUiSettingsStore
{
    private readonly string _stateFile;

    public LauncherUiSettingsStore(string? stateFile = null)
    {
        _stateFile = stateFile ?? LauncherPaths.LauncherUiStateFile;
    }

    public LauncherUiSettings Load()
    {
        try
        {
            if (!File.Exists(_stateFile))
            {
                return new LauncherUiSettings();
            }

            return JsonSerializer.Deserialize<LauncherUiSettings>(
                       File.ReadAllText(_stateFile),
                       JsonOptions.Default)
                   ?? new LauncherUiSettings();
        }
        catch (Exception exception)
        {
            LauncherLog.Warning($"Could not read launcher UI state. Using defaults: {exception.Message}");
            return new LauncherUiSettings();
        }
    }

    public void Save(LauncherUiSettings settings)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(_stateFile)!);
        var temporaryFile = _stateFile + $".tmp-{Guid.NewGuid():N}";

        try
        {
            File.WriteAllText(temporaryFile, JsonSerializer.Serialize(settings, JsonOptions.Default));
            File.Move(temporaryFile, _stateFile, overwrite: true);
        }
        catch (Exception exception)
        {
            LauncherLog.Warning($"Could not save launcher UI state: {exception.Message}");
        }
        finally
        {
            try
            {
                if (File.Exists(temporaryFile))
                {
                    File.Delete(temporaryFile);
                }
            }
            catch (Exception exception)
            {
                LauncherLog.Warning($"Could not remove temporary launcher UI state: {exception.Message}");
            }
        }
    }
}

internal sealed class LauncherUiSettings
{
    public int Schema { get; init; } = 1;
    public double WindowWidth { get; init; } = 980;
    public double WindowHeight { get; init; } = 640;
    public double ProgramsPanelRatio { get; init; } = 0.52;
    public List<double> ProgramColumnWidths { get; init; } = [];
    public List<double> ModuleColumnWidths { get; init; } = [];
}
