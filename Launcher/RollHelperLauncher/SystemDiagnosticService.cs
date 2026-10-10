using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Windows;
using System.Windows.Media;

namespace RollHelperLauncher;

public enum DiagnosticSeverity
{
    Success,
    Warning,
    Error,
    Info
}

public sealed record DiagnosticCheckItem(
    string Category,
    string Title,
    DiagnosticSeverity Severity,
    string Summary,
    string? Recommendation = null
);

public sealed record DiagnosticReport(
    IReadOnlyList<DiagnosticCheckItem> Items,
    bool HasElevationClash,
    bool CanElevateLauncher
)
{
    public bool HasCriticalErrors => Items.Any(i => i.Severity == DiagnosticSeverity.Error);
    public bool HasWarnings => Items.Any(i => i.Severity == DiagnosticSeverity.Warning);
}

public static class SystemDiagnosticService
{
    private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    private const uint TOKEN_QUERY = 0x0008;
    private const int TokenElevation = 20;
    private const uint MOD_NOREPEAT = 0x4000;
    private const int VK_F1 = 0x70;
    private const int VK_OEM_3 = 0xC0; // Tilde ~

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(
        IntPtr TokenHandle,
        int TokenInformationClass,
        IntPtr TokenInformation,
        uint TokenInformationLength,
        out uint ReturnLength);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public static bool IsCurrentProcessElevated()
    {
        try
        {
            using var identity = WindowsIdentity.GetCurrent();
            var principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
        catch
        {
            return false;
        }
    }

    public static bool? IsProcessElevated(int processId)
    {
        var hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, processId);
        if (hProc == IntPtr.Zero)
            return null;

        try
        {
            if (!OpenProcessToken(hProc, TOKEN_QUERY, out var hToken))
                return null;

            try
            {
                var elevationSize = Marshal.SizeOf<int>();
                var pElevation = Marshal.AllocHGlobal(elevationSize);
                try
                {
                    if (GetTokenInformation(hToken, TokenElevation, pElevation, (uint)elevationSize, out _))
                    {
                        var isElevated = Marshal.ReadInt32(pElevation) != 0;
                        return isElevated;
                    }
                    return null;
                }
                finally
                {
                    Marshal.FreeHGlobal(pElevation);
                }
            }
            finally
            {
                CloseHandle(hToken);
            }
        }
        finally
        {
            CloseHandle(hProc);
        }
    }

    public static async Task<DiagnosticReport> RunFullDiagnosticAsync(Visual? windowVisual = null)
    {
        var items = new List<DiagnosticCheckItem>();
        var isLauncherElevated = IsCurrentProcessElevated();
        var hasElevationClash = false;

        // 1. Поиск Syrve процессов
        var syrveNames = new[] { "BackOffice", "iikoOffice", "iikoFront.Net", "resto", "Syrve" };
        var foundSyrveProcesses = new List<Process>();

        foreach (var proc in Process.GetProcesses())
        {
            try
            {
                if (syrveNames.Any(name => proc.ProcessName.Contains(name, StringComparison.OrdinalIgnoreCase))
                    || (!string.IsNullOrEmpty(proc.MainWindowTitle) &&
                        (proc.MainWindowTitle.Contains("Syrve", StringComparison.OrdinalIgnoreCase) ||
                         proc.MainWindowTitle.Contains("iiko", StringComparison.OrdinalIgnoreCase))))
                {
                    foundSyrveProcesses.Add(proc);
                }
            }
            catch
            {
                // Access denied or process exited
            }
        }

        // 2. Проверка прав (UIPI конфликт администратора)
        var anySyrveElevated = false;
        if (foundSyrveProcesses.Count > 0)
        {
            foreach (var sp in foundSyrveProcesses)
            {
                var elevated = IsProcessElevated(sp.Id);
                if (elevated == true)
                {
                    anySyrveElevated = true;
                    break;
                }
            }

            if (anySyrveElevated && !isLauncherElevated)
            {
                hasElevationClash = true;
                items.Add(new DiagnosticCheckItem(
                    Category: "Права доступа (UAC / UIPI)",
                    Title: "КРИТИЧЕСКИЙ СБОЙ: Syrve запущен от Администратора!",
                    Severity: DiagnosticSeverity.Error,
                    Summary: "Syrve работает от имени Администратора, а RollHelper запущен с обычными правами. Windows UIPI наглухо блокирует ввод клавиш (F1, Enter, ~) и текст в окно Syrve. Палочки и заказы не смогут вноситься!",
                    Recommendation: "Нажмите кнопку «Перезапустить от Администратора» ниже, чтобы RollHelper получил равные права с Syrve."
                ));
            }
            else if (isLauncherElevated)
            {
                items.Add(new DiagnosticCheckItem(
                    Category: "Права доступа (UAC / UIPI)",
                    Title: "RollHelper запущен с правами Администратора",
                    Severity: DiagnosticSeverity.Success,
                    Summary: "RollHelper имеет полные права Администратора. Блокировка передачи нажатий в Syrve исключена."
                ));
            }
            else
            {
                items.Add(new DiagnosticCheckItem(
                    Category: "Права доступа (UAC / UIPI)",
                    Title: "Права согласованы (Обычный пользователь)",
                    Severity: DiagnosticSeverity.Success,
                    Summary: "И RollHelper, и Syrve работают с одинаковыми правами. Конфликта блокировки нет."
                ));
            }

            var syrveProc = foundSyrveProcesses[0];
            items.Add(new DiagnosticCheckItem(
                Category: "Процесс Syrve",
                Title: $"Syrve обнаружен: {syrveProc.ProcessName} (PID {syrveProc.Id})",
                Severity: DiagnosticSeverity.Success,
                Summary: $"Окно программы активно. Заголовок: {(string.IsNullOrEmpty(syrveProc.MainWindowTitle) ? "Фоновое окно" : syrveProc.MainWindowTitle)}."
            ));
        }
        else
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Процесс Syrve",
                Title: "Syrve не обнаружен",
                Severity: DiagnosticSeverity.Info,
                Summary: "Программа Syrve / iiko сейчас не запущена на этом ПК. Запустите Syrve перед началом работы с заказами.",
                Recommendation: "Если вы планируете запускать Syrve от Администратора, обязательно запускайте и RollHelper от Администратора."
            ));
        }

        // 3. Проверка доступности клавиши F1 (Пробитие палочек / СІВ)
        var f1Status = TestHotkeyAvailability(VK_F1);
        if (f1Status.Success)
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Горячие клавиши",
                Title: "Клавиша F1 свободна (Пробитие СІВ)",
                Severity: DiagnosticSeverity.Success,
                Summary: "Горячая клавиша F1 не занята другими программами и готова для ввода палочек."
            ));
        }
        else
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Горячие клавиши",
                Title: "Клавиша F1 заблокирована другой программой!",
                Severity: DiagnosticSeverity.Warning,
                Summary: "Клавиша F1 уже перехвачена сторонним приложением в Windows (например, Punto Switcher, Discord, GeForce Experience или софт клавиатуры). Нажатие F1 не дойдёт до RollHelper!",
                Recommendation: "Закройте конфликтующие программы в трее Windows или смените горячую клавишу в настройках RollHelper."
            ));
        }

        // 4. Проверка доступности клавиши ~ (Тильда - вызов пульта)
        var tildeStatus = TestHotkeyAvailability(VK_OEM_3);
        if (tildeStatus.Success)
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Горячие клавиши",
                Title: "Клавиша ~ (Тильда) свободна (Пульт заказов)",
                Severity: DiagnosticSeverity.Success,
                Summary: "Клавиша вызова пульта заказов свободна в системе."
            ));
        }
        else
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Горячие клавиши",
                Title: "Клавиша ~ перехвачена сторонним приложением",
                Severity: DiagnosticSeverity.Warning,
                Summary: "Клавиша ~ (Тильда) занята другим софтом. Вызов пульта по нажатию может не срабатывать.",
                Recommendation: "Проверьте переключатели раскладки или Punto Switcher."
            ));
        }

        // 5. Проверка масштаба экрана Windows (DPI)
        var dpiScale = 1.0;
        if (windowVisual is not null)
        {
            var dpi = VisualTreeHelper.GetDpi(windowVisual);
            dpiScale = dpi.DpiScaleX;
        }

        var percent = (int)Math.Round(dpiScale * 100);
        if (percent == 100)
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Экран и масштабирование",
                Title: "Масштаб экрана 100% (Оптимально)",
                Severity: DiagnosticSeverity.Success,
                Summary: "Масштаб Windows равен 100% (96 DPI). Все клики и координаты работают со 100% точностью."
            ));
        }
        else
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Экран и масштабирование",
                Title: $"Масштаб экрана Windows: {percent}%",
                Severity: DiagnosticSeverity.Warning,
                Summary: $"Масштабирование Windows установлено на {percent}%. На некоторых экранах экранные координаты могут смещаться.",
                Recommendation: "Рекомендуется выставить 100% в настройках экрана Windows (Параметры → Система → Дисплей → Масштаб)."
            ));
        }

        // 6. Проверка локального моста (HTTP порт 8000)
        var bridgeActive = await CheckBridgeServerAsync();
        if (bridgeActive)
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Локальный мост Syrve",
                Title: "Сервер моста активен (порт 8000)",
                Severity: DiagnosticSeverity.Success,
                Summary: "Локальный сервер iiko-моста отвечает. Быстрое чтение заказов без эмуляции мыши доступно."
            ));
        }
        else
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Локальный мост Syrve",
                Title: "Сервер моста не активен",
                Severity: DiagnosticSeverity.Info,
                Summary: "Локальный Python-сервер моста в данный момент не запущен (запускается автоматически при старте RollClub)."
            ));
        }

        // 7. Проверка демона AutoHotkey
        var ahkProcesses = Process.GetProcessesByName("AutoHotkeyU64")
            .Concat(Process.GetProcessesByName("AutoHotkey"))
            .ToList();

        if (ahkProcesses.Count > 0)
        {
            var ahkProc = ahkProcesses[0];
            items.Add(new DiagnosticCheckItem(
                Category: "Демон RollHelper",
                Title: $"Скрипт запущен: {ahkProc.ProcessName} (PID {ahkProc.Id})",
                Severity: DiagnosticSeverity.Success,
                Summary: "Фоновый скрипт RollHelper сейчас активен и готов к работе."
            ));
        }
        else
        {
            items.Add(new DiagnosticCheckItem(
                Category: "Демон RollHelper",
                Title: "Скрипт RollHelper не запущен",
                Severity: DiagnosticSeverity.Info,
                Summary: "Скрипт автоматизации пока не запущен. Нажмите кнопку «Запустить» в окне лаунчера."
            ));
        }

        return new DiagnosticReport(
            Items: items,
            HasElevationClash: hasElevationClash,
            CanElevateLauncher: !isLauncherElevated
        );
    }

    private static (bool Success, int ErrorCode) TestHotkeyAvailability(int virtualKey)
    {
        const int testId = 0xBEEF;
        if (RegisterHotKey(IntPtr.Zero, testId, MOD_NOREPEAT, (uint)virtualKey))
        {
            UnregisterHotKey(IntPtr.Zero, testId);
            return (true, 0);
        }

        var errorCode = Marshal.GetLastWin32Error();
        return (false, errorCode);
    }

    private static async Task<bool> CheckBridgeServerAsync()
    {
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromMilliseconds(400) };
            var response = await client.GetAsync("http://127.0.0.1:8000/api/health");
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public static bool RestartLauncherAsAdministrator()
    {
        try
        {
            var exePath = Environment.ProcessPath;
            if (string.IsNullOrEmpty(exePath) || !File.Exists(exePath))
                return false;

            var startInfo = new ProcessStartInfo
            {
                FileName = exePath,
                UseShellExecute = true,
                Verb = "runas"
            };

            Process.Start(startInfo);
            Application.Current.Shutdown();
            return true;
        }
        catch
        {
            return false;
        }
    }
}
