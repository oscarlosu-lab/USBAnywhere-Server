// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Settings Window Code-Behind
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

using System.Windows;
using USBAnywhere.Server.Services;

namespace USBAnywhere.Server.Views;

/// <summary>
/// Settings window for configuring application preferences
/// </summary>
public partial class SettingsWindow : Window
{
    private readonly LocalizationService _localization;
    private readonly string _currentLanguage;

    public SettingsWindow()
    {
        InitializeComponent();
        _localization = new LocalizationService();
        _currentLanguage = SettingsService.Current.Language ?? LocalizationService.DetectSystemLanguage();

        ApplyLocalization();
        LoadSettings();
    }

    private void ApplyLocalization()
    {
        Title = _localization.GetText("settings_title", _currentLanguage);
        txtTitle.Text = _localization.GetText("settings_title", _currentLanguage);
        txtSubtitle.Text = _localization.GetText("settings_subtitle", _currentLanguage);

        secGeneral.Text = _localization.GetText("sec_general", _currentLanguage);
        chkStartWithWindows.Content = _localization.GetText("chk_start_windows", _currentLanguage);
        chkStartMinimized.Content = _localization.GetText("chk_start_minimized", _currentLanguage);
        chkShowNotifications.Content = _localization.GetText("chk_show_notifications", _currentLanguage);
        chkCheckUpdates.Content = _localization.GetText("chk_check_updates", _currentLanguage);

        secAutoBind.Text = _localization.GetText("sec_autobind", _currentLanguage);
        chkAutoBind.Content = _localization.GetText("chk_autobind", _currentLanguage);
        txtAutoBindDesc.Text = _localization.GetText("desc_autobind", _currentLanguage);

        secSecurity.Text = _localization.GetText("sec_security", _currentLanguage);
        chkWhitelist.Content = _localization.GetText("chk_whitelist", _currentLanguage);

        secNetwork.Text = _localization.GetText("sec_network", _currentLanguage);
        btnFirewall.Content = _localization.GetText("btn_firewall", _currentLanguage);

        secAdvanced.Text = _localization.GetText("sec_advanced", _currentLanguage);
        lblRefreshInterval.Text = _localization.GetText("lbl_refresh_interval", _currentLanguage);
        lblSeconds.Text = _localization.GetText("lbl_seconds", _currentLanguage);

        secBackup.Text = _localization.GetText("sec_backup", _currentLanguage);
        btnExport.Content = _localization.GetText("btn_export", _currentLanguage);
        btnImport.Content = _localization.GetText("btn_import", _currentLanguage);

        btnReset.Content = _localization.GetText("btn_reset", _currentLanguage);
        btnCancel.Content = _localization.GetText("btn_cancel", _currentLanguage);
        btnSave.Content = _localization.GetText("btn_save", _currentLanguage);
    }

    private void LoadSettings()
    {
        var settings = SettingsService.Current;

        chkStartWithWindows.IsChecked = settings.StartWithWindows;
        chkStartMinimized.IsChecked = settings.StartMinimized;
        chkShowNotifications.IsChecked = settings.ShowNotifications;
        chkCheckUpdates.IsChecked = settings.CheckForUpdates;

        chkAutoBind.IsChecked = settings.AutoBindEnabled;

        chkWhitelist.IsChecked = settings.WhitelistEnabled;

        UpdateFirewallStatus(FirewallService.IsRuleConfigured() || settings.FirewallConfigured);

        txtRefreshInterval.Text = settings.RefreshIntervalSeconds.ToString();
    }

    private void SaveSettings()
    {
        var settings = SettingsService.Current;

        settings.StartWithWindows = chkStartWithWindows.IsChecked ?? false;
        settings.StartMinimized = chkStartMinimized.IsChecked ?? false;
        settings.ShowNotifications = chkShowNotifications.IsChecked ?? true;
        settings.CheckForUpdates = chkCheckUpdates.IsChecked ?? true;

        settings.AutoBindEnabled = chkAutoBind.IsChecked ?? false;

        settings.WhitelistEnabled = chkWhitelist.IsChecked ?? false;

        if (int.TryParse(txtRefreshInterval.Text, out int interval) && interval >= 1 && interval <= 60)
        {
            settings.RefreshIntervalSeconds = interval;
        }

        SettingsService.Save();
        StartupService.SyncWithSettings();
    }

    private void UpdateFirewallStatus(bool configured)
    {
        if (configured)
        {
            txtFirewallStatus.Text = _localization.GetText("fw_configured", _currentLanguage);
            txtFirewallStatus.Foreground = new System.Windows.Media.SolidColorBrush(
                System.Windows.Media.Color.FromRgb(39, 174, 96));
        }
        else
        {
            txtFirewallStatus.Text = _localization.GetText("fw_not_configured", _currentLanguage);
            txtFirewallStatus.Foreground = new System.Windows.Media.SolidColorBrush(
                System.Windows.Media.Color.FromRgb(241, 196, 15));
        }
    }

    private async void BtnFirewall_Click(object sender, RoutedEventArgs e)
    {
        if (FirewallService.IsRuleConfigured())
        {
            var removeResult = System.Windows.MessageBox.Show(
                _localization.GetText("fw_already_prompt", _currentLanguage),
                _localization.GetText("fw_already_title", _currentLanguage),
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (removeResult == MessageBoxResult.Yes)
            {
                btnFirewall.IsEnabled = false;
                var removed = await FirewallService.RemoveRuleAsync();
                btnFirewall.IsEnabled = true;
                UpdateFirewallStatus(!removed);
            }
            return;
        }

        var result = System.Windows.MessageBox.Show(
            _localization.GetText("fw_confirm_prompt", _currentLanguage),
            _localization.GetText("fw_confirm_title", _currentLanguage),
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (result == MessageBoxResult.Yes)
        {
            btnFirewall.IsEnabled = false;
            var success = await FirewallService.CreateRuleAsync();
            btnFirewall.IsEnabled = true;

            UpdateFirewallStatus(success);

            if (success)
            {
                System.Windows.MessageBox.Show(
                    _localization.GetText("fw_success_msg", _currentLanguage),
                    _localization.GetText("fw_success_title", _currentLanguage),
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
            }
            else
            {
                System.Windows.MessageBox.Show(
                    _localization.GetText("fw_error_msg", _currentLanguage),
                    _localization.GetText("fw_error_title", _currentLanguage),
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);
            }
        }
    }

    private void BtnExport_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new Microsoft.Win32.SaveFileDialog
        {
            Filter = "JSON files (*.json)|*.json",
            FileName = "usbanywhere-server-settings.json",
            Title = _localization.GetText("export_title", _currentLanguage)
        };

        if (dialog.ShowDialog() == true)
        {
            if (SettingsService.Export(dialog.FileName))
            {
                System.Windows.MessageBox.Show(
                    _localization.GetFormattedText("export_success_msg", _currentLanguage, dialog.FileName),
                    _localization.GetText("export_success_title", _currentLanguage),
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
            }
        }
    }

    private void BtnImport_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new Microsoft.Win32.OpenFileDialog
        {
            Filter = "JSON files (*.json)|*.json",
            Title = _localization.GetText("import_title", _currentLanguage)
        };

        if (dialog.ShowDialog() == true)
        {
            if (SettingsService.Import(dialog.FileName))
            {
                LoadSettings();
                System.Windows.MessageBox.Show(
                    _localization.GetText("import_success_msg", _currentLanguage),
                    _localization.GetText("import_success_title", _currentLanguage),
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
            }
            else
            {
                System.Windows.MessageBox.Show(
                    _localization.GetText("import_fail_msg", _currentLanguage),
                    _localization.GetText("import_fail_title", _currentLanguage),
                    MessageBoxButton.OK,
                    MessageBoxImage.Error);
            }
        }
    }

    private void BtnReset_Click(object sender, RoutedEventArgs e)
    {
        var result = System.Windows.MessageBox.Show(
            _localization.GetText("reset_prompt", _currentLanguage),
            _localization.GetText("reset_title", _currentLanguage),
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.Yes)
        {
            SettingsService.Reset();
            LoadSettings();
        }
    }

    private void BtnCancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }

    private void BtnSave_Click(object sender, RoutedEventArgs e)
    {
        SaveSettings();
        DialogResult = true;
        Close();
    }
}
