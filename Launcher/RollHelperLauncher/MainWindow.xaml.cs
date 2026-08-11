using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;

namespace RollHelperLauncher;

public partial class MainWindow : Window
{
    private readonly ObservableCollection<PackageRow> _programs = [];
    private readonly ObservableCollection<PackageRow> _modules = [];
    private readonly List<ReleasePackage> _manifestPackages = [];
    private readonly ManifestClient _manifestClient = new();
    private readonly PackageStateStore _packageStateStore = new();
    private readonly LauncherUiSettingsStore _uiSettingsStore = new();
    private readonly PackageInstaller _packageInstaller;
    private readonly LauncherUpdater _launcherUpdater;
    private readonly LauncherConfig _config;
    private CancellationTokenSource? _operationCancellation;
    private LauncherRelease? _launcherUpdate;
    private bool _modulesPanelOpened;
    private double _programsPanelRatio = 0.52;

    public MainWindow()
    {
        InitializeComponent();

        _packageInstaller = new PackageInstaller(_manifestClient, _packageStateStore);
        _launcherUpdater = new LauncherUpdater(_manifestClient);
        _config = LauncherConfig.Load();
        ProgramsGrid.ItemsSource = _programs;
        ModulesGrid.ItemsSource = _modules;
        LauncherVersionText.Text = $"• версия {_launcherUpdater.CurrentVersion}";
        ApplyUiSettings(_uiSettingsStore.Load());

        Loaded += async (_, _) => await RefreshManifestAsync();
        Closed += (_, _) =>
        {
            SaveUiSettings();
            _operationCancellation?.Cancel();
            _manifestClient.Dispose();
        };
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e) => await RefreshManifestAsync();

    private async void InstallAndRunButton_Click(object sender, RoutedEventArgs e) => await InstallAndRunSelectedProgramAsync();

    private async void UpdateLauncherButton_Click(object sender, RoutedEventArgs e)
    {
        if (_launcherUpdate is null)
        {
            await RefreshManifestAsync();
        }

        if (_launcherUpdate is null)
        {
            SetStatus($"Установлена актуальная версия лаунчера {_launcherUpdater.CurrentVersion}");
            MessageBox.Show(
                this,
                $"У вас уже установлена актуальная версия лаунчера {_launcherUpdater.CurrentVersion}.",
                "Обновление лаунчера",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
            return;
        }

        await UpdateLauncherAsync();
    }

    private async void ProgramsGrid_MouseDoubleClick(object sender, MouseButtonEventArgs e) => await InstallAndRunSelectedProgramAsync();

    private void ProgramsGrid_MouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        if (e.OriginalSource is not DependencyObject source
            || FindVisualParent<DataGridRow>(source) is not null
            || FindVisualParent<DataGridColumnHeader>(source) is not null
            || FindVisualParent<ScrollBar>(source) is not null)
        {
            return;
        }

        ClearProgramSelection();
    }

    private void HideModulesButton_Click(object sender, RoutedEventArgs e) => ClearProgramSelection();

    private void PackagesSplitter_DragCompleted(object sender, DragCompletedEventArgs e) => CapturePanelRatio();

    private void MainWindow_PreviewKeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape && ModulesPanel.Visibility == Visibility.Visible)
        {
            ClearProgramSelection();
            e.Handled = true;
        }
    }

    private async void ModulesGrid_MouseDoubleClick(object sender, MouseButtonEventArgs e) => await InstallOrEnableSelectedModuleAsync();

    private async void InstallEnableModuleButton_Click(object sender, RoutedEventArgs e) => await InstallOrEnableSelectedModuleAsync();

    private void DisableModuleButton_Click(object sender, RoutedEventArgs e) => DisableSelectedModule();

    private void RemoveModuleButton_Click(object sender, RoutedEventArgs e) => RemoveSelectedModule();

    private async void ContextInstallModuleItem_Click(object sender, RoutedEventArgs e) => await InstallOrEnableSelectedModuleAsync();

    private void ContextDisableModuleItem_Click(object sender, RoutedEventArgs e) => DisableSelectedModule();

    private void ContextRemoveModuleItem_Click(object sender, RoutedEventArgs e) => RemoveSelectedModule();

    private void ProgramsGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        RefreshModulesForSelectedProgram();
        UpdateProgramActionButton();
        UpdateSelectionStatus();
    }

    private void ClearProgramSelection()
    {
        ProgramsGrid.UnselectAll();
        ProgramsGrid.SelectedItem = null;
        ProgramsGrid.CurrentItem = null;
        RefreshModulesForSelectedProgram();
        UpdateProgramActionButton();
        UpdateSelectionStatus();
    }

    private static T? FindVisualParent<T>(DependencyObject? child) where T : DependencyObject
    {
        var current = child;
        while (current is not null)
        {
            if (current is T match)
            {
                return match;
            }

            current = current is Visual
                ? VisualTreeHelper.GetParent(current)
                : LogicalTreeHelper.GetParent(current);
        }

        return null;
    }

    private void ModulesGrid_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdateModuleActionButtons();
        UpdateSelectionStatus();
    }

    private void ModuleContextMenu_Opened(object sender, RoutedEventArgs e)
    {
        if (ModulesGrid.SelectedItem is not PackageRow selectedRow)
        {
            ContextInstallModuleItem.IsEnabled = false;
            ContextDisableModuleItem.IsEnabled = false;
            ContextRemoveModuleItem.IsEnabled = false;
            return;
        }

        var installed = _packageInstaller.IsInstalled(selectedRow.Package);
        var enabled = _packageInstaller.IsEnabled(selectedRow.Package);
        var missingRequirements = _packageInstaller.GetMissingRequirements(selectedRow.Package);

        ContextInstallModuleItem.Header = installed && !enabled ? "Включить" : "Установить";
        ContextInstallModuleItem.IsEnabled = (!installed || !enabled) && missingRequirements.Count == 0;
        ContextDisableModuleItem.IsEnabled = installed && enabled;
        ContextRemoveModuleItem.IsEnabled = _packageInstaller.HasInstalledVersion(selectedRow.Package.Id);
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
        if (!BeginOperation("Загрузка списка программ..."))
        {
            return;
        }

        try
        {
            var selectedProgramId = (ProgramsGrid.SelectedItem as PackageRow)?.Package.Id;
            var manifestUri = new Uri(_config.ManifestUrl);
            var manifest = await _manifestClient.DownloadManifestAsync(manifestUri, _operationCancellation!.Token);
            _launcherUpdate = _launcherUpdater.IsUpdateAvailable(manifest.Launcher)
                ? manifest.Launcher
                : null;

            _manifestPackages.Clear();
            _manifestPackages.AddRange(manifest.Packages);
            _programs.Clear();

            foreach (var package in _manifestPackages
                         .Where(package => !IsModule(package))
                         .OrderBy(package => package.DisplayName ?? package.Id))
            {
                _programs.Add(CreateRow(package));
            }

            ProgramsGrid.SelectedItem = string.IsNullOrWhiteSpace(selectedProgramId)
                ? null
                : _programs.FirstOrDefault(row =>
                    string.Equals(row.Package.Id, selectedProgramId, StringComparison.OrdinalIgnoreCase));
            if (_programs.Count == 0)
            {
                RefreshModulesForSelectedProgram();
                SetStatus("Сейчас нет доступных программ");
            }
            else if (ProgramsGrid.SelectedItem is null)
            {
                RefreshModulesForSelectedProgram();
                SetStatus("Выберите программу");
            }

            LauncherLog.Info("Program and module lists displayed");
        }
        catch (OperationCanceledException)
        {
            SetStatus("Операция отменена");
            LauncherLog.Warning("Manifest refresh cancelled");
        }
        catch (Exception exception)
        {
            ShowOperationError("Не удалось загрузить список программ", exception);
        }
        finally
        {
            EndOperation();
            UpdateProgramActionButton();
            UpdateModuleActionButtons();
        }
    }

    private async Task InstallAndRunSelectedProgramAsync()
    {
        if (ProgramsGrid.SelectedItem is not PackageRow selectedRow)
        {
            return;
        }

        var package = selectedRow.Package;
        if (!BeginOperation($"Подготовка {selectedRow.DisplayName}..."))
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
            selectedRow.Status = "Запущено";
            SetStatus($"{selectedRow.DisplayName} запущено");
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
            RefreshAllStatuses();
        }
    }

    private async Task InstallOrEnableSelectedModuleAsync()
    {
        if (ModulesGrid.SelectedItem is not PackageRow selectedRow)
        {
            return;
        }

        var package = selectedRow.Package;
        var missingRequirements = _packageInstaller.GetMissingRequirements(package);
        if (missingRequirements.Count > 0)
        {
            SetStatus(BuildRequirementMessage(missingRequirements));
            return;
        }

        if (_packageInstaller.IsInstalled(package) && !_packageInstaller.IsEnabled(package))
        {
            try
            {
                _packageInstaller.SetEnabled(package, true);
                SetStatus($"Дополнение «{selectedRow.DisplayName}» включено");
                RefreshAllStatuses();
            }
            catch (Exception exception)
            {
                ShowOperationError($"Не удалось включить {selectedRow.DisplayName}", exception);
            }

            return;
        }

        if (!BeginOperation($"Установка дополнения {selectedRow.DisplayName}..."))
        {
            return;
        }

        try
        {
            var progress = new Progress<int>(value => DownloadProgress.Value = value);
            await _packageInstaller.InstallAsync(package, progress, _operationCancellation!.Token);
            _packageInstaller.SetEnabled(package, true);
            SetStatus($"Дополнение «{selectedRow.DisplayName}» установлено и включено");
        }
        catch (OperationCanceledException)
        {
            SetStatus("Установка дополнения отменена");
            LauncherLog.Warning($"Module installation cancelled: {package.Id}");
        }
        catch (Exception exception)
        {
            ShowOperationError($"Не удалось установить {selectedRow.DisplayName}", exception);
        }
        finally
        {
            EndOperation();
            RefreshAllStatuses();
        }
    }

    private void DisableSelectedModule()
    {
        if (ModulesGrid.SelectedItem is not PackageRow selectedRow)
        {
            return;
        }

        try
        {
            _packageInstaller.SetEnabled(selectedRow.Package, false);
            SetStatus($"Дополнение «{selectedRow.DisplayName}» отключено");
            RefreshAllStatuses();
        }
        catch (Exception exception)
        {
            ShowOperationError($"Не удалось отключить {selectedRow.DisplayName}", exception);
        }
    }

    private void RemoveSelectedModule()
    {
        if (ModulesGrid.SelectedItem is not PackageRow selectedRow)
        {
            LauncherLog.Warning("Remove module requested without a selected module");
            return;
        }

        LauncherLog.Info($"Remove module requested: {selectedRow.Package.Id}");

        var answer = MessageBox.Show(
            this,
            $"Удалить дополнение «{selectedRow.DisplayName}» со всеми установленными версиями?",
            "Удаление дополнения",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question,
            MessageBoxResult.No);

        if (answer != MessageBoxResult.Yes)
        {
            return;
        }

        try
        {
            _packageInstaller.Remove(selectedRow.Package);
            SetStatus($"Дополнение «{selectedRow.DisplayName}» удалено");
            RefreshAllStatuses();
        }
        catch (Exception exception)
        {
            ShowOperationError($"Не удалось удалить {selectedRow.DisplayName}", exception);
        }
    }

    private async Task UpdateLauncherAsync()
    {
        var release = _launcherUpdate;
        if (release is null || !BeginOperation($"Подготовка обновления лаунчера {release.Version}..."))
        {
            return;
        }

        try
        {
            var progress = new Progress<int>(value => DownloadProgress.Value = value);
            SetStatus($"Скачивание лаунчера {release.Version}...");
            await _launcherUpdater.PrepareAndRestartAsync(release, progress, _operationCancellation!.Token);

            SetStatus("Обновление готово. Перезапускаю лаунчер...");
            await Task.Delay(300);
            Application.Current.Shutdown();
        }
        catch (OperationCanceledException)
        {
            SetStatus("Обновление отменено");
            LauncherLog.Warning("Launcher update cancelled");
        }
        catch (Exception exception)
        {
            ShowOperationError("Не удалось обновить лаунчер", exception);
        }
        finally
        {
            EndOperation();
            UpdateProgramActionButton();
            UpdateModuleActionButtons();
        }
    }

    private void RefreshModulesForSelectedProgram()
    {
        _modules.Clear();

        if (ProgramsGrid.SelectedItem is not PackageRow selectedProgram)
        {
            SetModulesPanelVisibility(false);
            ModulesHeaderText.Text = "Дополнения";
            ModulesHintText.Text = "Сначала выберите программу слева";
            ModulesEmptyText.Text = "Выберите программу, чтобы увидеть дополнения";
            ModulesEmptyText.Visibility = Visibility.Visible;
            UpdateModuleActionButtons();
            return;
        }

        SetModulesPanelVisibility(true);
        ModulesHeaderText.Text = $"Дополнения для {selectedProgram.DisplayName}";
        ModulesHintText.Text = "Устанавливайте, временно отключайте или удаляйте модули";

        foreach (var package in _manifestPackages
                     .Where(package => IsModule(package)
                         && string.Equals(package.Extends, selectedProgram.Package.Id, StringComparison.OrdinalIgnoreCase))
                     .OrderBy(package => package.DisplayName ?? package.Id))
        {
            _modules.Add(CreateRow(package));
        }

        ModulesEmptyText.Text = "Для этой программы пока нет дополнений";
        ModulesEmptyText.Visibility = _modules.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        ModulesGrid.SelectedIndex = _modules.Count > 0 ? 0 : -1;
        UpdateModuleActionButtons();
    }

    private void SetModulesPanelVisibility(bool visible)
    {
        if (!visible && ModulesPanel.Visibility == Visibility.Visible)
        {
            CapturePanelRatio();
        }

        ModulesPanel.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;
        PackagesSplitter.Visibility = visible ? Visibility.Visible : Visibility.Collapsed;

        if (!visible)
        {
            ProgramsColumn.Width = new GridLength(1, GridUnitType.Star);
            SplitterColumn.Width = new GridLength(0);
            ModulesColumn.Width = new GridLength(0);
            return;
        }

        SplitterColumn.Width = new GridLength(16);
        if (!_modulesPanelOpened || ModulesColumn.Width.Value == 0)
        {
            ProgramsColumn.Width = new GridLength(_programsPanelRatio, GridUnitType.Star);
            ModulesColumn.Width = new GridLength(1 - _programsPanelRatio, GridUnitType.Star);
            _modulesPanelOpened = true;
        }
    }

    private void CapturePanelRatio()
    {
        var panelWidth = ProgramsColumn.ActualWidth + ModulesColumn.ActualWidth;
        if (panelWidth > 0 && ModulesColumn.ActualWidth > 0)
        {
            _programsPanelRatio = Math.Clamp(ProgramsColumn.ActualWidth / panelWidth, 0.25, 0.75);
        }
    }

    private void ApplyUiSettings(LauncherUiSettings settings)
    {
        var maximumWidth = Math.Max(MinWidth, SystemParameters.WorkArea.Width - 40);
        var maximumHeight = Math.Max(MinHeight, SystemParameters.WorkArea.Height - 40);
        Width = Math.Clamp(settings.WindowWidth, MinWidth, maximumWidth);
        Height = Math.Clamp(settings.WindowHeight, MinHeight, maximumHeight);
        _programsPanelRatio = Math.Clamp(settings.ProgramsPanelRatio, 0.25, 0.75);
        ApplyColumnWidths(ProgramsGrid, settings.ProgramColumnWidths);
        ApplyColumnWidths(ModulesGrid, settings.ModuleColumnWidths);
    }

    private void SaveUiSettings()
    {
        CapturePanelRatio();
        var bounds = WindowState == WindowState.Normal ? new Rect(Left, Top, ActualWidth, ActualHeight) : RestoreBounds;
        _uiSettingsStore.Save(new LauncherUiSettings
        {
            WindowWidth = bounds.Width,
            WindowHeight = bounds.Height,
            ProgramsPanelRatio = _programsPanelRatio,
            ProgramColumnWidths = ProgramsGrid.Columns.Select(column => column.ActualWidth).ToList(),
            ModuleColumnWidths = ModulesGrid.Columns.Select(column => column.ActualWidth).ToList()
        });
    }

    private static void ApplyColumnWidths(DataGrid grid, IReadOnlyList<double> widths)
    {
        for (var index = 0; index < grid.Columns.Count && index < widths.Count; index++)
        {
            if (double.IsFinite(widths[index]) && widths[index] >= 48)
            {
                grid.Columns[index].Width = new DataGridLength(widths[index]);
            }
        }
    }

    private PackageRow CreateRow(ReleasePackage package) => new(package, GetPackageStatus(package));

    private string GetPackageStatus(ReleasePackage package)
    {
        if (IsModule(package))
        {
            if (_packageInstaller.IsInstalled(package))
            {
                return _packageInstaller.IsEnabled(package) ? "Включено" : "Отключено";
            }

            if (_packageInstaller.HasInstalledVersion(package.Id))
            {
                return "Доступно обновление";
            }

            return _packageInstaller.GetMissingRequirements(package).Count > 0
                ? "Нужна программа"
                : "Доступно";
        }

        return _packageInstaller.IsInstalled(package)
            ? "Установлено"
            : _packageInstaller.HasInstalledVersion(package.Id)
                ? "Доступно обновление"
                : "Доступно";
    }

    private void RefreshAllStatuses()
    {
        foreach (var row in _programs)
        {
            row.Status = GetPackageStatus(row.Package);
        }

        var selectedModuleId = (ModulesGrid.SelectedItem as PackageRow)?.Package.Id;
        RefreshModulesForSelectedProgram();
        if (!string.IsNullOrWhiteSpace(selectedModuleId))
        {
            ModulesGrid.SelectedItem = _modules.FirstOrDefault(row =>
                string.Equals(row.Package.Id, selectedModuleId, StringComparison.OrdinalIgnoreCase));
        }

        ProgramsGrid.Items.Refresh();
        ModulesGrid.Items.Refresh();
        UpdateProgramActionButton();
        UpdateModuleActionButtons();
    }

    private bool BeginOperation(string status)
    {
        if (_operationCancellation is not null)
        {
            return false;
        }

        _operationCancellation = new CancellationTokenSource();
        RefreshButton.IsEnabled = false;
        UpdateLauncherButton.IsEnabled = false;
        InstallAndRunButton.IsEnabled = false;
        InstallEnableModuleButton.IsEnabled = false;
        DisableModuleButton.IsEnabled = false;
        RemoveModuleButton.IsEnabled = false;
        ProgramsGrid.IsEnabled = false;
        ModulesGrid.IsEnabled = false;
        DownloadProgress.Value = 0;
        SetStatus(status);
        return true;
    }

    private void EndOperation()
    {
        _operationCancellation?.Dispose();
        _operationCancellation = null;
        RefreshButton.IsEnabled = true;
        ProgramsGrid.IsEnabled = true;
        ModulesGrid.IsEnabled = true;
        DownloadProgress.Value = 0;
        UpdateLauncherButtonState();
    }

    private void UpdateProgramActionButton()
    {
        if (_operationCancellation is not null || ProgramsGrid.SelectedItem is not PackageRow selectedRow)
        {
            InstallAndRunButton.Content = "Выберите программу";
            InstallAndRunButton.IsEnabled = false;
            return;
        }

        InstallAndRunButton.Content = _packageInstaller.IsInstalled(selectedRow.Package)
            ? $"Запустить {selectedRow.DisplayName}"
            : _packageInstaller.HasInstalledVersion(selectedRow.Package.Id)
                ? $"Обновить {selectedRow.DisplayName} и запустить"
                : $"Установить {selectedRow.DisplayName} и запустить";
        InstallAndRunButton.IsEnabled = true;
    }

    private void UpdateModuleActionButtons()
    {
        if (_operationCancellation is not null || ModulesGrid.SelectedItem is not PackageRow selectedRow)
        {
            InstallEnableModuleButton.Content = "Установить";
            InstallEnableModuleButton.IsEnabled = false;
            DisableModuleButton.IsEnabled = false;
            RemoveModuleButton.IsEnabled = false;
            return;
        }

        var installed = _packageInstaller.IsInstalled(selectedRow.Package);
        var enabled = _packageInstaller.IsEnabled(selectedRow.Package);
        var missingRequirements = _packageInstaller.GetMissingRequirements(selectedRow.Package);

        InstallEnableModuleButton.Content = installed && !enabled ? "Включить" : "Установить";
        InstallEnableModuleButton.IsEnabled = (!installed || !enabled) && missingRequirements.Count == 0;
        DisableModuleButton.IsEnabled = installed && enabled;
        RemoveModuleButton.IsEnabled = _packageInstaller.HasInstalledVersion(selectedRow.Package.Id);
    }

    private void UpdateSelectionStatus()
    {
        if (_operationCancellation is not null)
        {
            return;
        }

        if (ModulesGrid.IsKeyboardFocusWithin && ModulesGrid.SelectedItem is PackageRow selectedModule)
        {
            var missingRequirements = _packageInstaller.GetMissingRequirements(selectedModule.Package);
            SetStatus(missingRequirements.Count > 0
                ? BuildRequirementMessage(missingRequirements)
                : $"{selectedModule.DisplayName} • версия {selectedModule.Version} • {selectedModule.Status.ToLowerInvariant()}");
            return;
        }

        if (ProgramsGrid.SelectedItem is PackageRow selectedProgram)
        {
            SetStatus($"{selectedProgram.DisplayName} • версия {selectedProgram.Version} • {selectedProgram.Status.ToLowerInvariant()}");
            return;
        }

        SetStatus(_programs.Count == 0 ? "Сейчас нет доступных программ" : "Выберите программу");
    }

    private string BuildRequirementMessage(IReadOnlyList<PackageRequirement> requirements)
    {
        var descriptions = requirements.Select(requirement =>
        {
            var packageName = _manifestPackages.FirstOrDefault(package =>
                string.Equals(package.Id, requirement.Id, StringComparison.OrdinalIgnoreCase))?.DisplayName
                ?? requirement.Id;
            return string.IsNullOrWhiteSpace(requirement.MinVersion)
                ? packageName
                : $"{packageName} {requirement.MinVersion} или новее";
        });

        return $"Сначала установите: {string.Join(", ", descriptions)}";
    }

    private void UpdateLauncherButtonState()
    {
        UpdateLauncherButton.Visibility = Visibility.Visible;
        UpdateLauncherButton.IsEnabled = _operationCancellation is null;
        UpdateLauncherButton.Content = _launcherUpdate is null
            ? "Проверить обновление лаунчера"
            : $"Обновить лаунчер до {_launcherUpdate.Version}";
    }

    private static bool IsModule(ReleasePackage package)
    {
        return string.Equals(package.Type, "module", StringComparison.OrdinalIgnoreCase);
    }

    private void SetStatus(string status) => StatusText.Text = status;

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
        public string Version => Package.Version;
        public string Status { get; set; }
    }
}
