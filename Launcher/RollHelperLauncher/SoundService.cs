using System;
using System.Collections.Generic;
using System.IO;
using System.Media;
using System.Text.Json;

namespace RollHelperLauncher;

public enum SoundTheme
{
    SoftChime = 0,
    ModernPing = 1,
    Subtle = 2,
    ClassicGentle = 3,
    Mute = 4
}

public sealed class SoundSettings
{
    public SoundTheme Theme { get; set; } = SoundTheme.SoftChime;
    public int Volume { get; set; } = 30; // 5 to 100
}

internal static class SoundService
{
    private static readonly string SettingsFile = Path.Combine(LauncherPaths.UserRoot, "sound_settings.json");

    public static SoundSettings LoadSettings()
    {
        try
        {
            if (File.Exists(SettingsFile))
            {
                var json = File.ReadAllText(SettingsFile);
                var settings = JsonSerializer.Deserialize<SoundSettings>(json);
                if (settings != null)
                {
                    settings.Volume = Math.Clamp(settings.Volume, 5, 100);
                    return settings;
                }
            }
        }
        catch
        {
            // fallback to default
        }

        return new SoundSettings();
    }

    public static void SaveSettings(SoundSettings settings)
    {
        settings.Volume = Math.Clamp(settings.Volume, 5, 100);
        try
        {
            Directory.CreateDirectory(LauncherPaths.UserRoot);
            var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsFile, json);
        }
        catch
        {
            // ignore
        }

        ApplySoundFiles(settings);
    }

    public static void PlayPreview(SoundTheme theme, bool isOk, int volume)
    {
        if (theme == SoundTheme.Mute)
        {
            return;
        }

        var wavBytes = GenerateWav(theme, isOk, volume);
        using var ms = new MemoryStream(wavBytes);
        using var player = new SoundPlayer(ms);
        player.Play();
    }

    public static void ApplySoundFiles(SoundSettings settings)
    {
        var okBytes = GenerateWav(settings.Theme, "ok", settings.Volume);
        var errBytes = GenerateWav(settings.Theme, "err", settings.Volume);
        var futureBytes = GenerateWav(settings.Theme, "future", settings.Volume);

        var targetDirs = new List<string>
        {
            Path.Combine(LauncherPaths.ProgramRoot, "UserData", "sounds"),
            Path.Combine(LauncherPaths.UserRoot, "sounds"),
            Path.Combine(LauncherPaths.ProgramRoot, "UserData", "rollclub")
        };

        // Also deploy to installed packages so existing scripts immediately pick them up
        if (Directory.Exists(LauncherPaths.PackagesDirectory))
        {
            foreach (var packageDir in Directory.GetDirectories(LauncherPaths.PackagesDirectory))
            {
                foreach (var verDir in Directory.GetDirectories(packageDir))
                {
                    targetDirs.Add(verDir);
                    var rhSub = Path.Combine(verDir, "RollHelper");
                    if (Directory.Exists(rhSub))
                    {
                        targetDirs.Add(rhSub);
                    }
                }
            }
        }

        foreach (var dir in targetDirs)
        {
            try
            {
                Directory.CreateDirectory(dir);
                File.WriteAllBytes(Path.Combine(dir, "beep_ok.wav"), okBytes);
                File.WriteAllBytes(Path.Combine(dir, "beep_err.wav"), errBytes);
                File.WriteAllBytes(Path.Combine(dir, "beep_future.wav"), futureBytes);
            }
            catch
            {
                // ignore
            }
        }
    }

    public static byte[] GenerateWav(SoundTheme theme, bool isOk, int volumePercent)
    {
        return GenerateWav(theme, isOk ? "ok" : "err", volumePercent);
    }

    public static byte[] GenerateWav(SoundTheme theme, string soundType, int volumePercent)
    {
        if (theme == SoundTheme.Mute)
        {
            return CreateSilenceWav(0.05);
        }

        double volFactor = Math.Clamp(volumePercent / 100.0, 0.05, 1.0);
        // Master ceiling to prevent harsh distortion even at 100%
        volFactor *= 0.55;

        var notes = new List<(double startRatio, double freq, double decay, double amp)>();
        double duration;

        switch (theme)
        {
            case SoundTheme.SoftChime:
                if (soundType == "ok")
                {
                    // Gentle major interval: D5 -> A5
                    duration = 0.35;
                    notes.Add((0.00, 587.33, 11.0, 0.70));
                    notes.Add((0.08, 880.00, 9.0, 0.85));
                }
                else if (soundType == "future")
                {
                    // Gentle ascending triad: C5 -> E5 -> G5
                    duration = 0.45;
                    notes.Add((0.00, 523.25, 10.0, 0.70));
                    notes.Add((0.10, 659.25, 10.0, 0.75));
                    notes.Add((0.20, 783.99, 8.0, 0.85));
                }
                else
                {
                    // Gentle descending interval: A4 -> E4
                    duration = 0.40;
                    notes.Add((0.00, 440.00, 11.0, 0.75));
                    notes.Add((0.10, 329.63, 9.0, 0.75));
                }
                break;

            case SoundTheme.ModernPing:
                if (soundType == "ok")
                {
                    // Short elegant UI bell: C6
                    duration = 0.22;
                    notes.Add((0.00, 1046.50, 14.0, 0.90));
                }
                else if (soundType == "future")
                {
                    // Modern alert: A5 -> C6
                    duration = 0.30;
                    notes.Add((0.00, 880.00, 14.0, 0.80));
                    notes.Add((0.10, 1046.50, 12.0, 0.85));
                }
                else
                {
                    // Soft double-tap: C5 -> G#4
                    duration = 0.30;
                    notes.Add((0.00, 523.25, 14.0, 0.80));
                    notes.Add((0.08, 415.30, 12.0, 0.80));
                }
                break;

            case SoundTheme.Subtle:
                if (soundType == "ok")
                {
                    // Low-key warm tap: A4
                    duration = 0.16;
                    notes.Add((0.00, 440.00, 22.0, 0.65));
                }
                else if (soundType == "future")
                {
                    // Low-key alert: G4 -> A4
                    duration = 0.26;
                    notes.Add((0.00, 392.00, 18.0, 0.70));
                    notes.Add((0.10, 440.00, 16.0, 0.70));
                }
                else
                {
                    // Low-key double-tap: D4 -> B3
                    duration = 0.24;
                    notes.Add((0.00, 293.66, 18.0, 0.70));
                    notes.Add((0.08, 246.94, 16.0, 0.70));
                }
                break;

            case SoundTheme.ClassicGentle:
            default:
                if (soundType == "ok")
                {
                    // Classic 880Hz but softened with smooth envelope
                    duration = 0.25;
                    notes.Add((0.00, 880.00, 8.0, 0.80));
                }
                else if (soundType == "future")
                {
                    duration = 0.35;
                    notes.Add((0.00, 659.25, 9.0, 0.75));
                    notes.Add((0.12, 880.00, 8.0, 0.80));
                }
                else
                {
                    // Classic two-tone: 440Hz -> 311Hz
                    duration = 0.40;
                    notes.Add((0.00, 440.00, 8.0, 0.80));
                    notes.Add((0.12, 311.13, 7.0, 0.80));
                }
                break;
        }

        return Synthesize(notes, duration, volFactor);
    }

    private static byte[] Synthesize(List<(double startRatio, double freq, double decay, double amp)> notes, double duration, double volume)
    {
        const int sampleRate = 44100;
        int nSamples = (int)(duration * sampleRate);
        var pcm = new short[nSamples];

        for (int i = 0; i < nSamples; i++)
        {
            double t = (double)i / sampleRate;
            double val = 0.0;

            foreach (var (startRatio, freq, decay, amp) in notes)
            {
                double startT = startRatio * duration;
                if (t >= startT)
                {
                    double dt = t - startT;
                    // 10ms smooth attack ramp to eliminate clicks
                    double envAttack = Math.Min(1.0, dt / 0.010);
                    // Exponential decay
                    double envDecay = Math.Exp(-decay * dt);
                    // Fundamental + subtle 2nd harmonic (octave) for warmth
                    double sig = Math.Sin(2.0 * Math.PI * freq * dt) + 0.22 * Math.Sin(2.0 * Math.PI * freq * 2.0 * dt);
                    val += sig * envAttack * envDecay * amp;
                }
            }

            double sampleVal = val * volume * 32767.0;
            pcm[i] = (short)Math.Clamp(sampleVal, -32767.0, 32767.0);
        }

        int dataSize = nSamples * sizeof(short);
        using var ms = new MemoryStream(44 + dataSize);
        using var writer = new BinaryWriter(ms);

        // WAV Header
        writer.Write(new[] { 'R', 'I', 'F', 'F' });
        writer.Write(36 + dataSize);
        writer.Write(new[] { 'W', 'A', 'V', 'E' });
        writer.Write(new[] { 'f', 'm', 't', ' ' });
        writer.Write(16); // Subchunk1Size
        writer.Write((short)1); // PCM
        writer.Write((short)1); // Mono
        writer.Write(sampleRate);
        writer.Write(sampleRate * sizeof(short)); // ByteRate
        writer.Write((short)sizeof(short)); // BlockAlign
        writer.Write((short)16); // BitsPerSample
        writer.Write(new[] { 'd', 'a', 't', 'a' });
        writer.Write(dataSize);

        // PCM data
        for (int i = 0; i < nSamples; i++)
        {
            writer.Write(pcm[i]);
        }

        return ms.ToArray();
    }

    private static byte[] CreateSilenceWav(double duration)
    {
        const int sampleRate = 44100;
        int nSamples = (int)(duration * sampleRate);
        int dataSize = nSamples * sizeof(short);

        using var ms = new MemoryStream(44 + dataSize);
        using var writer = new BinaryWriter(ms);

        writer.Write(new[] { 'R', 'I', 'F', 'F' });
        writer.Write(36 + dataSize);
        writer.Write(new[] { 'W', 'A', 'V', 'E' });
        writer.Write(new[] { 'f', 'm', 't', ' ' });
        writer.Write(16);
        writer.Write((short)1);
        writer.Write((short)1);
        writer.Write(sampleRate);
        writer.Write(sampleRate * sizeof(short));
        writer.Write((short)sizeof(short));
        writer.Write((short)16);
        writer.Write(new[] { 'd', 'a', 't', 'a' });
        writer.Write(dataSize);

        for (int i = 0; i < nSamples; i++)
        {
            writer.Write((short)0);
        }

        return ms.ToArray();
    }
}
