using System.Globalization;
using System.Windows;
using System.Windows.Data;
using System.Windows.Media;

namespace RollHelperLauncher;

public partial class DiagnosticWindow : Window
{
    public DiagnosticWindow()
    {
        InitializeComponent();
        Loaded += async (_, _) => await RunDiagnosticAsync();
    }

    private async Task RunDiagnosticAsync()
    {
        AlertBanner.Visibility = Visibility.Collapsed;
        AlertBannerButton.Visibility = Visibility.Collapsed;
        ElevateAdminFooterButton.Visibility = Visibility.Collapsed;

        var report = await SystemDiagnosticService.RunFullDiagnosticAsync(this);
        DiagnosticItemsList.ItemsSource = report.Items;

        if (report.HasElevationClash)
        {
            AlertBanner.Visibility = Visibility.Visible;
            AlertBanner.Background = new SolidColorBrush(Color.FromRgb(0xFE, 0xE2, 0xE2));
            AlertBanner.BorderBrush = new SolidColorBrush(Color.FromRgb(0xF8, 0x71, 0x71));
            AlertBannerTitle.Foreground = new SolidColorBrush(Color.FromRgb(0x99, 0x1B, 0x1B));
            AlertBannerTitle.Text = "⛔ КРИТИЧЕСКАЯ БЛОКИРОВКА: Syrve запущен от Администратора!";
            AlertBannerText.Foreground = new SolidColorBrush(Color.FromRgb(0x7F, 0x1D, 0x1D));
            AlertBannerText.Text = "Из-за защиты Windows UIPI скрипт RollHelper не может отправлять палочки по F1 и заполнять поля в окне Администратора. Перезапустите RollHelper с правами Администратора.";
            AlertBannerButton.Visibility = Visibility.Visible;
            ElevateAdminFooterButton.Visibility = Visibility.Visible;
        }
        else if (report.HasCriticalErrors)
        {
            AlertBanner.Visibility = Visibility.Visible;
            AlertBanner.Background = new SolidColorBrush(Color.FromRgb(0xFF, 0xFB, 0xEB));
            AlertBanner.BorderBrush = new SolidColorBrush(Color.FromRgb(0xFC, 0xD3, 0x4D));
            AlertBannerTitle.Foreground = new SolidColorBrush(Color.FromRgb(0x92, 0x40, 0x0E));
            AlertBannerTitle.Text = "⚠ Обнаружены проблемы конфигурации горячих клавиш";
            AlertBannerText.Foreground = new SolidColorBrush(Color.FromRgb(0x78, 0x35, 0x0F));
            AlertBannerText.Text = "Ознакомьтесь с рекомендациями ниже для восстановления работы горячих клавиш.";
        }
        else
        {
            AlertBanner.Visibility = Visibility.Visible;
            AlertBanner.Background = new SolidColorBrush(Color.FromRgb(0xEC, 0xFD, 0xF5));
            AlertBanner.BorderBrush = new SolidColorBrush(Color.FromRgb(0xA7, 0xF3, 0xD0));
            AlertBannerTitle.Foreground = new SolidColorBrush(Color.FromRgb(0x06, 0x5F, 0x46));
            AlertBannerTitle.Text = "✅ Рабочее место готово: клавиша F1 и права доступа в порядке";
            AlertBannerText.Foreground = new SolidColorBrush(Color.FromRgb(0x04, 0x78, 0x57));
            AlertBannerText.Text = "Блокировок UIPI нет, горячие клавиши свободны, масштаб экрана проверен.";
        }
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        await RunDiagnosticAsync();
    }

    private void ElevateButton_Click(object sender, RoutedEventArgs e)
    {
        var result = MessageBox.Show(
            this,
            "RollHelper будет перезапущен с правами Администратора.\n\nПродолжить?",
            "Перезапуск от Администратора",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (result == MessageBoxResult.Yes)
        {
            if (!SystemDiagnosticService.RestartLauncherAsAdministrator())
            {
                MessageBox.Show(
                    this,
                    "Не удалось запросить повышение прав Windows. Пожалуйста, закройте лаунчер и запустите его через правый клик: «Запуск от имени администратора».",
                    "Ошибка запуска",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        }
    }

    private void CloseButton_Click(object sender, RoutedEventArgs e)
    {
        Close();
    }
}

public sealed class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        return string.IsNullOrWhiteSpace(value as string) ? Visibility.Collapsed : Visibility.Visible;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}
