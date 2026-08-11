using System.Text;

namespace RollHelperLauncher;

internal static class LauncherLog
{
    private static readonly object SyncRoot = new();
    private static string? _logFile;

    public static void Initialize(string logFile)
    {
        _logFile = logFile;
        Directory.CreateDirectory(Path.GetDirectoryName(logFile)!);
    }

    public static void Info(string message) => Write("INFO", message, null);

    public static void Warning(string message) => Write("WARN", message, null);

    public static void Error(string message, Exception? exception = null) => Write("ERROR", message, exception);

    private static void Write(string level, string message, Exception? exception)
    {
        try
        {
            var builder = new StringBuilder();
            builder.Append(DateTimeOffset.Now.ToString("yyyy-MM-dd HH:mm:ss.fff zzz"));
            builder.Append(" [").Append(level).Append("] ").Append(message);

            if (exception is not null)
            {
                builder.AppendLine();
                builder.Append(exception);
            }

            builder.AppendLine();

            lock (SyncRoot)
            {
                if (!string.IsNullOrWhiteSpace(_logFile))
                {
                    File.AppendAllText(_logFile, builder.ToString(), Encoding.UTF8);
                }
            }
        }
        catch
        {
            // Logging must never stop the launcher.
        }
    }
}
