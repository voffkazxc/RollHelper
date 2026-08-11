using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Input;

namespace RollHelperLauncher;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<PackageRow> _packages = [];
    private readonly ManifestClient _manifestClient = new();
    private readonly PackageInstaller _packageInstaller;
    private readonly LauncherConfig _config;
    private CancellationTokenSource? _operationCancellation;

    public MainWindow()
    {
        InitializeComponent();

        _packageInstaller = new PackageInstaller(_manifestClient);
        _config = LauncherConfig.Load();
        PackagesGrid.ItemsSource = _packages;

        Loaded += async (_, _) => await RefreshManifestAsync();
        Closed += (_, _) =>
        {
            _operationCancellation?.Cancel();
            _manifestClient.Dispose();
        };
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        await RefreshManifestAsync();
    }

    private async void InstallAndRunButton_Click(object sender, RoutedEventArgs e)
    {
        await InstallAndRunSelectedAsync();
    }

    private async void PackagesGrid_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        await InstallAndRunSelectedAsync();
    }

    private void PackagesGrid_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        UpdateActionButton();
        UpdateSelectionStatus();
    }

    private void OpenLogButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            LauncherLog.Info("Opening launcher log");
            Process.Start(new ProcessStartInfo
            {
                FileName = LauncherPaths.LogFile,
                UseShellExecute = true
            });
        }
        catch (Exception exception)
        {
            ShowOperationError("Не удалось открыть launcher.log", exception);
        }
    }

    private async Task RefreshManifestAsync()
    {
        if (!BeginOperation("Загрузка списка пакетов..."))
        {
            return;
        }

        try
        {
            var manifestUri = new Uri(_config.ManifestUrl);
            var manifest = await _manifestClient.DownloadManifestAsync(manifestUri, _operationCancellation!.Token);

            _packages.Clear();
            foreach (var package in manifest.Packages.OrderBy(item => item.DisplayName ?? item.Id))
            {
                var status = _packageInstaller.IsInstalled(package)
                    ? "Установлен"
                    : _packageInstaller.HasInstalledVersion(package.Id)
                        ? "Доступно обновление"
                        : "Доступен";
                _packages.Add(new PackageRow(
                    package,
                    status));
            }

            PackagesGrid.SelectedIndex = -1;
            SetStatus(_packages.Count == 0
                ? "Сейчас нет доступных программ и дополнений"
                : "Выберите программу или дополнение");
            LauncherLog.Info("Package list displayed");
        }
        catch (OperationCanceledException)
        {
            SetStatus("Операция отменена");
            LauncherLog.Warning("Manifest refresh cancelled");
        }
        catch (Exception exception)
        {
            ShowOperationError("Не удалось загрузить список пакетов", exception);
        }
        finally
        {
            EndOperation();
            UpdateActionButton();
        }
    }

    private async Task InstallAndRunSelectedAsync()
    {
        if (PackagesGrid.SelectedItem is not PackageRow selectedRow)
        {
            return;
        }

        var package = selectedRow.Package;
        if (!BeginOperation($"Подготовка пакета {selectedRow.DisplayName}..."))
        {
            return;
        }

        try
        {
            var progress = new Progress<int>(value => DownloadProgress.Value = value);
            SetStatus($"Скачивание и установка {selectedRow.DisplayName}...");
            await _packageInstaller.InstallAsync(package, progress, _operationCancellation!.Token);

            SetStatus($"Запуск {selectedRow.DisplayName}...");
            _packageInstaller.Launch(package);

            selectedRow.Status = "Запущен";
            PackagesGrid.Items.Refresh();
            SetStatus($"{selectedRow.DisplayName} запущен");
        }
        catch (OperationCanceledException)
        {
            SetStatus("Операция отменена");
            LauncherLog.Warning($"Package operation cancelled: {package.Id}");
        }
        catch (Exception exception)
        {
            ShowOperationError($"Не удалось установить или запустить {selectedRow.DisplayName}", exception);
        }
        finally
        {
            EndOperation();
            UpdateActionButton();
        }
    }

    private bool BeginOperation(string status)
    {
        if (_operationCancellation is not null)
        {
            return false;
        }

        _operationCancellation = new CancellationTokenSource();
        RefreshButton.IsEnabled = false;
        InstallAndRunButton.IsEnabled = false;
        PackagesGrid.IsEnabled = false;
        DownloadProgress.Value = 0;
        SetStatus(status);
        return true;
    }

    private void EndOperation()
    {
        _operationCancellation?.Dispose();
        _operationCancellation = null;
        RefreshButton.IsEnabled = true;
        PackagesGrid.IsEnabled = true;
        DownloadProgress.Value = 0;
    }

    private void UpdateActionButton()
    {
        if (_operationCancellation is not null || PackagesGrid.SelectedItem is not PackageRow selectedRow)
        {
            InstallAndRunButton.Content = "Выберите компонент";
            InstallAndRunButton.IsEnabled = false;
            return;
        }

        InstallAndRunButton.Content = _packageInstaller.IsInstalled(selectedRow.Package)
            ? "Запустить"
            : _packageInstaller.HasInstalledVersion(selectedRow.Package.Id)
                ? "Обновить и запустить"
                : "Установить и запустить";
        InstallAndRunButton.IsEnabled = true;
    }

    private void UpdateSelectionStatus()
    {
        if (_operationCancellation is not null)
        {
            return;
        }

        if (PackagesGrid.SelectedItem is PackageRow selectedRow)
        {
            SetStatus($"{selectedRow.DisplayName} • версия {selectedRow.Version} • {selectedRow.Status.ToLowerInvariant()}");
            return;
        }

        SetStatus(_packages.Count == 0
            ? "Сейчас нет доступных программ и дополнений"
            : "Выберите программу или дополнение");
    }

    private void SetStatus(string status)
    {
        StatusText.Text = status;
    }

    private void ShowOperationError(string title, Exception exception)
    {
        LauncherLog.Error(title, exception);
        SetStatus(title);
        MessageBox.Show(
            this,
            $"{title}.\n\n{exception.Message}\n\nПодробности: {LauncherPaths.LogFile}",
            "RollHelper Launcher",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
    }

    private sealed class PackageRow
    {
        public PackageRow(ReleasePackage package, string status)
        {
            Package = package;
            Status = status;
        }

        public ReleasePackage Package { get; }
        public string DisplayName => Package.DisplayName ?? Package.Id;
        public string Type => Package.Type?.ToLowerInvariant() switch
        {
            "brand" => "Программа",
            "module" => "Дополнение",
            "tool" => "Инструмент",
            _ => "Компонент"
        };
        public string Version => Package.Version;
        public string Status { get; set; }
    }
}
