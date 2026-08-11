using System.Windows;
using System.Windows.Threading;

namespace RollHelperLauncher;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        try
        {
            LauncherPaths.EnsureDirectories();
            LauncherLog.Initialize(LauncherPaths.LogFile);
            LauncherLog.Info("RollHelperLauncher started");

            DispatcherUnhandledException += OnDispatcherUnhandledException;
            new MainWindow().Show();
        }
        catch (Exception exception)
        {
            LauncherLog.Error("Fatal launcher startup error", exception);
            MessageBox.Show(
                $"Лаунчер не может запуститься.\n\n{exception.Message}\n\nЛог: {LauncherPaths.LogFile}",
                "RollHelper Launcher",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        LauncherLog.Info("RollHelperLauncher stopped");
        base.OnExit(e);
    }

    private static void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        LauncherLog.Error("Unhandled UI error", e.Exception);
        MessageBox.Show(
            $"Произошла непредвиденная ошибка.\n\n{e.Exception.Message}\n\nЛог: {LauncherPaths.LogFile}",
            "RollHelper Launcher",
            MessageBoxButton.OK,
            MessageBoxImage.Error);
        e.Handled = true;
    }
}
