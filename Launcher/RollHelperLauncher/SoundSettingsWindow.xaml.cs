using System;
using System.Windows;
using System.Windows.Controls;

namespace RollHelperLauncher;

public partial class SoundSettingsWindow : Window
{
    private SoundSettings _currentSettings;

    public SoundSettingsWindow()
    {
        InitializeComponent();
        _currentSettings = SoundService.LoadSettings();

        // Initialize UI values
        int themeIdx = (int)_currentSettings.Theme;
        if (themeIdx >= 0 && themeIdx < ThemeComboBox.Items.Count)
        {
            ThemeComboBox.SelectedIndex = themeIdx;
        }
        else
        {
            ThemeComboBox.SelectedIndex = 0;
        }

        VolumeSlider.Value = _currentSettings.Volume;
        VolumeValueText.Text = $"{_currentSettings.Volume}%";
    }

    private SoundTheme GetSelectedTheme()
    {
        if (ThemeComboBox.SelectedItem is ComboBoxItem item && int.TryParse(item.Tag?.ToString(), out int val))
        {
            return (SoundTheme)val;
        }
        return SoundTheme.SoftChime;
    }

    private int GetCurrentVolume()
    {
        return (int)Math.Round(VolumeSlider.Value);
    }

    private void VolumeSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (VolumeValueText != null)
        {
            VolumeValueText.Text = $"{(int)Math.Round(e.NewValue)}%";
        }
    }

    private void ThemeComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        bool isMute = GetSelectedTheme() == SoundTheme.Mute;
        if (TestOkButton != null) TestOkButton.IsEnabled = !isMute;
        if (TestErrButton != null) TestErrButton.IsEnabled = !isMute;
        if (VolumeSlider != null) VolumeSlider.IsEnabled = !isMute;
    }

    private void TestOkButton_Click(object sender, RoutedEventArgs e)
    {
        SoundService.PlayPreview(GetSelectedTheme(), isOk: true, GetCurrentVolume());
    }

    private void TestErrButton_Click(object sender, RoutedEventArgs e)
    {
        SoundService.PlayPreview(GetSelectedTheme(), isOk: false, GetCurrentVolume());
    }

    private void SaveButton_Click(object sender, RoutedEventArgs e)
    {
        _currentSettings.Theme = GetSelectedTheme();
        _currentSettings.Volume = GetCurrentVolume();

        SoundService.SaveSettings(_currentSettings);
        DialogResult = true;
        Close();
    }

    private void CancelButton_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
