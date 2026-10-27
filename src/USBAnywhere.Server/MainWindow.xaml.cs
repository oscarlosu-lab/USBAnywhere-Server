// ═══════════════════════════════════════════════════════════════════════════════
// USBAnywhere Server - USB/IP Server GUI for Windows
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Linked with USBAnywhere Client - https://github.com/oscarlosu-lab/USBAnywhere
// Licensed under GPL v3 - See LICENSE file
// ═══════════════════════════════════════════════════════════════════════════════

using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Principal;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using USBAnywhere.Server.Models;
using USBAnywhere.Server.Services;
using Color = System.Windows.Media.Color;
using WinForms = System.Windows.Forms;

namespace USBAnywhere.Server;

/// <summary>
/// GUI Wrapper for usbipd-win — Part of the USBAnywhere v3.0 Ecosystem
/// </summary>
public partial class MainWindow : Window
{
    private readonly record struct ServerLogEntry(DateTime Timestamp, string? Key, object[] Args, string? RawMessage);

    private readonly UsbipdService _usbipdService;
    private readonly DriverInstaller _driverInstaller;
    private readonly UpdateService _updateService;
    private readonly LocalizationService _localization;
    private readonly DispatcherTimer _refreshTimer;
    private readonly ObservableCollection<LocalUsbDevice> _deviceCollection = new();
    private readonly HashSet<string> _autoBindingBusIds = new();
    private readonly List<ServerLogEntry> _logHistory = new();
    private WinForms.NotifyIcon? _notifyIcon;
    private WinForms.ToolStripMenuItem? _trayOpenItem;
    private WinForms.ToolStripMenuItem? _trayExitItem;
    private string _currentLanguage = "en";
    private string _currentTheme = "dark";
    private string _primaryIp = "127.0.0.1";

    public MainWindow()
    {
        InitializeComponent();

        dgDevices.ItemsSource = _deviceCollection;

        _usbipdService = new UsbipdService();
        _driverInstaller = new DriverInstaller();
        _updateService = new UpdateService();
        _localization = new LocalizationService();

        _currentLanguage = SettingsService.Current.Language ?? LocalizationService.DetectSystemLanguage();
        _currentTheme = SettingsService.Current.Theme ?? "dark";

        InitializeNotifyIcon();

        _usbipdService.LogMessage += OnLogMessage;
        _driverInstaller.LogMessage += OnLogMessage;

        var interval = Math.Clamp(SettingsService.Current.RefreshIntervalSeconds, 1, 60);
        _refreshTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(interval) };
        _refreshTimer.Tick += (s, e) => RefreshDeviceList();
        _refreshTimer.Start();

        AddLocalizedLog("log_server_started");
        LogService.Info("MainWindow initialized");
        UpdateBadges();
        UpdateUITexts();
        ThemeService.ApplyTheme(_currentTheme);

        Loaded += MainWindow_Loaded;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        var cmdArgs = Environment.GetCommandLineArgs();
        bool forceMinimized = cmdArgs.Any(a => a.Equals("--minimized", StringComparison.OrdinalIgnoreCase))
                              || SettingsService.Current.StartMinimized;
        bool autoInstallDriver = cmdArgs.Any(a => a.Equals("--install-driver", StringComparison.OrdinalIgnoreCase));

        if (forceMinimized)
        {
            WindowState = WindowState.Minimized;
            Hide();
        }

        await CheckDriverAndRefreshAsync(autoInstallDriver);

        if (SettingsService.Current.CheckForUpdates)
        {
            _ = CheckUpdatesSilentlyAsync();
        }
    }

    private async Task CheckUpdatesSilentlyAsync()
    {
        try
        {
            var info = await _updateService.CheckForUpdatesAsync();
            if (info.UpdateAvailable)
            {
                AddLocalizedLog("log_update_available", info.LatestVersion);
            }
        }
        catch (Exception ex)
        {
            LogService.Debug($"Silent update check skipped: {ex.Message}");
        }
    }

    private void InitializeNotifyIcon()
    {
        _notifyIcon = new WinForms.NotifyIcon
        {
            Text = "USBAnywhere Server",
            Visible = true
        };

        try
        {
            var exePath = Process.GetCurrentProcess().MainModule?.FileName;
            if (!string.IsNullOrEmpty(exePath))
            {
                _notifyIcon.Icon = System.Drawing.Icon.ExtractAssociatedIcon(exePath);
            }
        }
        catch (Exception ex)
        {
            LogService.Debug($"NotifyIcon icon extraction skipped: {ex.Message}");
        }

        _notifyIcon.DoubleClick += (s, e) => RestoreWindow();

        var contextMenu = new WinForms.ContextMenuStrip();
        _trayOpenItem = new WinForms.ToolStripMenuItem(_localization.GetText("tray_open", _currentLanguage), null, (s, e) => RestoreWindow());
        _trayExitItem = new WinForms.ToolStripMenuItem(_localization.GetText("tray_exit", _currentLanguage), null, (s, e) =>
        {
            if (_notifyIcon != null)
            {
                _notifyIcon.Visible = false;
            }
            Close();
        });

        contextMenu.Items.Add(_trayOpenItem);
        contextMenu.Items.Add(new WinForms.ToolStripSeparator());
        contextMenu.Items.Add(_trayExitItem);

        _notifyIcon.ContextMenuStrip = contextMenu;
    }

    private void RestoreWindow()
    {
        Show();
        WindowState = WindowState.Normal;
        Activate();
    }

    protected override void OnStateChanged(EventArgs e)
    {
        if (WindowState == WindowState.Minimized)
        {
            Hide();
            NotificationService.ShowToast(
                "USBAnywhere Server",
                _localization.GetText("tray_minimized", _currentLanguage),
                NotificationType.Info,
                _notifyIcon);
        }
        base.OnStateChanged(e);
    }

    private void UpdateBadges()
    {
        bool isAdmin = IsRunningAsAdmin();
        adminBadge.Background = new SolidColorBrush(isAdmin ? Color.FromRgb(39, 174, 96) : Color.FromRgb(231, 76, 60));
        txtAdminStatus.Text = isAdmin
            ? _localization.GetText("badge_admin", _currentLanguage)
            : _localization.GetText("badge_user", _currentLanguage);

        modeBadge.Background = new SolidColorBrush(PathService.IsPortable ? Color.FromRgb(52, 152, 219) : Color.FromRgb(155, 89, 182));
        txtModeStatus.Text = PathService.IsPortable
            ? _localization.GetText("badge_portable", _currentLanguage)
            : _localization.GetText("badge_installed", _currentLanguage);

        _primaryIp = GetLocalIPv4Address();
        txtServerIp.Text = $"IP: {_primaryIp}:3240";
    }

    private static string GetLocalIPv4Address()
    {
        try
        {
            foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up ||
                    ni.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                {
                    continue;
                }

                var props = ni.GetIPProperties();
                if (props.GatewayAddresses.Count == 0)
                {
                    continue;
                }

                foreach (var ua in props.UnicastAddresses)
                {
                    if (ua.Address.AddressFamily == AddressFamily.InterNetwork)
                    {
                        return ua.Address.ToString();
                    }
                }
            }
        }
        catch (Exception ex)
        {
            LogService.Debug($"Failed to enumerate network interfaces: {ex.Message}");
        }
        return "127.0.0.1";
    }

    private void IpBadge_Click(object sender, MouseButtonEventArgs e)
    {
        try
        {
            System.Windows.Clipboard.SetText(_primaryIp);
            AddLocalizedLog("log_ip_copied", _primaryIp);
        }
        catch (Exception ex)
        {
            Log($"⚠️ {ex.Message}");
        }
    }

    private static bool IsRunningAsAdmin()
    {
        using var identity = WindowsIdentity.GetCurrent();
        var principal = new WindowsPrincipal(identity);
        return principal.IsInRole(WindowsBuiltInRole.Administrator);
    }

    private async Task CheckDriverAndRefreshAsync(bool forceInstall = false)
    {
        if (!_driverInstaller.IsUsbipdInstalled())
        {
            AddLocalizedLog("log_driver_not_installed");

            bool shouldInstall = forceInstall;
            if (!shouldInstall)
            {
                var promptMsg = _localization.GetText("driver_missing_prompt", _currentLanguage);
                var promptTitle = _localization.GetText("driver_missing_title", _currentLanguage);

                var result = System.Windows.MessageBox.Show(
                    promptMsg,
                    promptTitle,
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Question);

                shouldInstall = result == MessageBoxResult.Yes;
            }

            if (shouldInstall)
            {
                AddLocalizedLog("log_driver_installing");
                var success = await _driverInstaller.InstallUsbipdAsync();
                if (success)
                {
                    AddLocalizedLog("log_driver_installed_ok");
                    _usbipdService.Reinitialize();
                    AddLocalizedLog("log_service_reinitialized");
                }
                else
                {
                    AddLocalizedLog("log_driver_install_fail");
                    UpdateStatus();
                    return;
                }
            }
            else
            {
                AddLocalizedLog("log_driver_skipped");
                UpdateStatus();
                return;
            }
        }
        else
        {
            AddLocalizedLog("log_driver_detected");
        }

        await RefreshDeviceListAsync();
        UpdateStatus();
    }

    private void RefreshDeviceList()
    {
        _ = RefreshDeviceListAsync();
    }

    private async Task RefreshDeviceListAsync()
    {
        try
        {
            var devices = await _usbipdService.GetDevicesAsync();
            var incomingBusIds = new HashSet<string>(devices.Select(d => d.BusId));

            for (int i = _deviceCollection.Count - 1; i >= 0; i--)
            {
                if (!incomingBusIds.Contains(_deviceCollection[i].BusId))
                {
                    _deviceCollection.RemoveAt(i);
                }
            }

            foreach (var dev in devices)
            {
                dev.SetLanguage(_currentLanguage);
                var existing = _deviceCollection.FirstOrDefault(d => d.BusId == dev.BusId);
                if (existing != null)
                {
                    existing.VendorId = dev.VendorId;
                    existing.ProductId = dev.ProductId;
                    existing.Name = dev.Name;
                    existing.Description = dev.Description;
                    existing.Status = dev.Status;
                    existing.IsExported = dev.IsExported;
                    existing.IsNotShared = dev.IsNotShared;
                    existing.SetLanguage(_currentLanguage);
                }
                else
                {
                    _deviceCollection.Add(dev);
                }

                if (SettingsService.Current.AutoBindEnabled &&
                    dev.IsNotShared &&
                    !string.IsNullOrWhiteSpace(dev.VidPid) &&
                    SettingsService.Current.AutoBindDevices.Contains(dev.VidPid) &&
                    !_autoBindingBusIds.Contains(dev.BusId))
                {
                    _autoBindingBusIds.Add(dev.BusId);
                    AddLocalizedLog("log_autobind_trigger", dev.DisplayName, dev.BusId);
                    NotificationService.ShowToast(
                        _localization.GetText("title", _currentLanguage),
                        _localization.GetFormattedText("log_autobind_trigger", _currentLanguage, dev.DisplayName, dev.BusId),
                        NotificationType.Success,
                        _notifyIcon);
                    _ = Task.Run(async () =>
                    {
                        try
                        {
                            await _usbipdService.BindDeviceAsync(dev.BusId);
                        }
                        finally
                        {
                            Dispatcher.Invoke(() => _autoBindingBusIds.Remove(dev.BusId));
                        }
                    });
                }
            }

            txtDeviceCount.Text = _localization.GetFormattedText("device_count", _currentLanguage, _deviceCollection.Count);
        }
        catch (Exception ex)
        {
            AddLocalizedLog("log_refresh_error", ex.Message);
        }
    }

    private void UpdateStatus()
    {
        if (_usbipdService.IsUsbipdAvailable)
        {
            statusIndicator.Fill = new SolidColorBrush(Color.FromRgb(0, 210, 106));
            txtStatus.Text = _localization.GetText("status_running", _currentLanguage);
            txtStatus.Foreground = new SolidColorBrush(Color.FromRgb(0, 210, 106));
        }
        else
        {
            statusIndicator.Fill = new SolidColorBrush(Color.FromRgb(231, 76, 60));
            txtStatus.Text = _localization.GetText("status_not_available", _currentLanguage);
            txtStatus.Foreground = new SolidColorBrush(Color.FromRgb(231, 76, 60));
        }
    }

    private void BtnRefresh_Click(object sender, RoutedEventArgs e)
    {
        UpdateBadges();
        RefreshDeviceList();
        AddLocalizedLog("log_list_refreshed");
    }

    private async void BtnShareAll_Click(object sender, RoutedEventArgs e)
    {
        var unshared = _deviceCollection.Where(d => d.IsNotShared).ToList();
        if (unshared.Count == 0)
        {
            AddLocalizedLog("log_share_all_all_done");
            return;
        }

        btnShareAll.IsEnabled = false;
        try
        {
            int sharedCount = 0;
            foreach (var dev in unshared)
            {
                if (await _usbipdService.BindDeviceAsync(dev.BusId))
                {
                    sharedCount++;
                    RememberAutoBindDevice(dev.VidPid, add: true);
                }
            }
            AddLocalizedLog("log_share_all_result", sharedCount, unshared.Count);
            await RefreshDeviceListAsync();
        }
        finally
        {
            btnShareAll.IsEnabled = true;
        }
    }

    private void BtnClient_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            System.Windows.Clipboard.SetText(_primaryIp);
        }
        catch (Exception ex)
        {
            LogService.Debug($"Clipboard copy skipped: {ex.Message}");
        }

        string[] candidatePaths =
        [
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "USBAnywhere", "USBAnywhere.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "USBAnywhere", "USBAnywhere.exe"),
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "USBAnywhere", "USBAnywhere.exe")
        ];

        var clientExe = candidatePaths.FirstOrDefault(File.Exists);
        if (!string.IsNullOrEmpty(clientExe))
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = clientExe,
                    UseShellExecute = true
                });
                AddLocalizedLog("log_client_launched", clientExe, _primaryIp);
                return;
            }
            catch (Exception ex)
            {
                Log($"⚠️ Could not launch client directly: {ex.Message}");
            }
        }

        var msg = _localization.GetFormattedText("client_prompt_msg", _currentLanguage, _primaryIp);
        var title = _localization.GetText("client_prompt_title", _currentLanguage);

        if (System.Windows.MessageBox.Show(msg, title, MessageBoxButton.YesNo, MessageBoxImage.Information) == MessageBoxResult.Yes)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://github.com/oscarlosu-lab/USBAnywhere/releases/latest",
                UseShellExecute = true
            });
        }
    }

    private void BtnClearLog_Click(object sender, RoutedEventArgs e)
    {
        lock (_logHistory)
        {
            _logHistory.Clear();
        }
        txtLog.Clear();
    }

    private void BtnMinimizeToTray_Click(object sender, RoutedEventArgs e)
    {
        WindowState = WindowState.Minimized;
    }

    private void BtnSettings_Click(object sender, RoutedEventArgs e)
    {
        var settingsWindow = new Views.SettingsWindow
        {
            Owner = this
        };
        if (settingsWindow.ShowDialog() == true)
        {
            AddLocalizedLog("log_settings_saved");
            ApplySettings();
        }
    }

    private void ApplySettings()
    {
        var interval = Math.Clamp(SettingsService.Current.RefreshIntervalSeconds, 1, 60);
        _refreshTimer.Interval = TimeSpan.FromSeconds(interval);
    }

    private void BtnDiagnostics_Click(object sender, RoutedEventArgs e)
    {
        string diagnostics = PathService.GetDiagnosticReport();
        diagnostics += "\n" + _localization.GetFormattedText("diag_server_ip", _currentLanguage, _primaryIp);
        if (LogService.CurrentLogFile != null)
        {
            diagnostics += "\n" + _localization.GetFormattedText("diag_current_log", _currentLanguage, LogService.CurrentLogFile);
        }
        System.Windows.MessageBox.Show(
            diagnostics,
            _localization.GetText("diag_title", _currentLanguage),
            MessageBoxButton.OK,
            MessageBoxImage.Information);
        AddLocalizedLog("log_diagnostics_shown");
    }

    private async void BtnBind_Click(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button btn && btn.Tag is string busId)
        {
            btn.IsEnabled = false;
            try
            {
                var dev = _deviceCollection.FirstOrDefault(d => d.BusId == busId);
                var success = await _usbipdService.BindDeviceAsync(busId);
                if (success && dev != null)
                {
                    RememberAutoBindDevice(dev.VidPid, add: true);
                    NotificationService.ShowToast(
                        _localization.GetText("title", _currentLanguage),
                        _localization.GetFormattedText("log_device_shared", _currentLanguage, dev.DisplayName),
                        NotificationType.Success,
                        _notifyIcon);
                }
                await RefreshDeviceListAsync();
            }
            finally
            {
                btn.IsEnabled = true;
            }
        }
    }

    private async void BtnUnbind_Click(object sender, RoutedEventArgs e)
    {
        if (sender is System.Windows.Controls.Button btn && btn.Tag is string busId)
        {
            btn.IsEnabled = false;
            try
            {
                var dev = _deviceCollection.FirstOrDefault(d => d.BusId == busId);
                var success = await _usbipdService.UnbindDeviceAsync(busId);
                if (success && dev != null)
                {
                    RememberAutoBindDevice(dev.VidPid, add: false);
                    NotificationService.ShowToast(
                        _localization.GetText("title", _currentLanguage),
                        _localization.GetFormattedText("log_device_stopped", _currentLanguage, dev.DisplayName),
                        NotificationType.Info,
                        _notifyIcon);
                }
                await RefreshDeviceListAsync();
            }
            finally
            {
                btn.IsEnabled = true;
            }
        }
    }

    private static void RememberAutoBindDevice(string? vidPid, bool add)
    {
        if (string.IsNullOrWhiteSpace(vidPid))
            return;

        var list = SettingsService.Current.AutoBindDevices;
        if (add)
        {
            if (!list.Contains(vidPid))
            {
                list.Add(vidPid);
                SettingsService.Save();
            }
        }
        else
        {
            if (list.Remove(vidPid))
            {
                SettingsService.Save();
            }
        }
    }

    private async void BtnUninstall_Click(object sender, RoutedEventArgs e)
    {
        var msg = _localization.GetText("driver_uninstall_prompt", _currentLanguage);
        var title = _localization.GetText("driver_uninstall_title", _currentLanguage);

        var result = System.Windows.MessageBox.Show(
            msg,
            title,
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);

        if (result == MessageBoxResult.Yes)
        {
            AddLocalizedLog("log_uninstalling_driver");
            var success = await _driverInstaller.UninstallUsbipdAsync();
            if (success)
            {
                AddLocalizedLog("log_driver_uninstalled");
                _usbipdService.Reinitialize();
                UpdateStatus();
            }
        }
    }

    private async void BtnUpdate_Click(object sender, RoutedEventArgs e)
    {
        UpdateStatusBar(_localization.GetText("update_checking_status", _currentLanguage), Color.FromRgb(52, 152, 219));
        AddLocalizedLog("log_checking_updates");

        try
        {
            var updateInfo = await _updateService.CheckForUpdatesAsync();

            AddLocalizedLog("log_update_status", updateInfo.CurrentVersion, updateInfo.LatestVersion);

            if (updateInfo.UpdateAvailable)
            {
                AddLocalizedLog("log_update_available", updateInfo.LatestVersion);
                UpdateStatusBar(_localization.GetFormattedText("log_update_available", _currentLanguage, updateInfo.LatestVersion), Color.FromRgb(241, 196, 15));

                var prompt = _localization.GetFormattedText("update_available_prompt", _currentLanguage, updateInfo.LatestVersion, updateInfo.ReleaseNotes ?? "");
                var title = _localization.GetText("update_available_title", _currentLanguage);

                var result = System.Windows.MessageBox.Show(
                    prompt,
                    title,
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Information);

                if (result == MessageBoxResult.Yes &&
                    updateInfo.DownloadUrl != null &&
                    updateInfo.InstallerName != null)
                {
                    AddLocalizedLog("log_update_downloading");
                    UpdateStatusBar(_localization.GetText("update_downloading_status", _currentLanguage), Color.FromRgb(52, 152, 219));

                    var installResult = await _updateService.StartUpdateAsync(
                        updateInfo.DownloadUrl,
                        updateInfo.InstallerName,
                        updateInfo.Sha256SumsUrl);

                    if (!installResult.Success)
                    {
                        AddLocalizedLog("log_update_failed", installResult.Error ?? "");
                        UpdateStatusBar(_localization.GetFormattedText("update_error_status", _currentLanguage, installResult.Error ?? ""), Color.FromRgb(231, 76, 60));
                    }
                }
            }
            else
            {
                AddLocalizedLog("log_update_latest", updateInfo.CurrentVersion);
                UpdateStatusBar(_localization.GetFormattedText("log_update_latest", _currentLanguage, updateInfo.CurrentVersion), Color.FromRgb(46, 204, 113));
            }
        }
        catch (Exception ex)
        {
            AddLocalizedLog("log_update_failed", ex.Message);
            UpdateStatusBar(_localization.GetFormattedText("update_error_status", _currentLanguage, ex.Message), Color.FromRgb(231, 76, 60));
        }
    }

    private void BtnLanguage_Click(object sender, RoutedEventArgs e)
    {
        _currentLanguage = _currentLanguage == "es" ? "en" : "es";
        SettingsService.Current.Language = _currentLanguage;
        SettingsService.Save();

        foreach (var dev in _deviceCollection)
        {
            dev.SetLanguage(_currentLanguage);
        }
        dgDevices.Items.Refresh();

        UpdateBadges();
        UpdateUITexts();
        UpdateStatus();
        AddLocalizedLog("log_lang_changed");
    }

    private void BtnTheme_Click(object sender, RoutedEventArgs e)
    {
        _currentTheme = _currentTheme == "dark" ? "light" : "dark";
        ThemeService.ApplyTheme(_currentTheme);
        btnTheme.Content = ThemeService.GetThemeIcon(_currentTheme);
        AddLocalizedLog("log_theme_changed", _currentTheme == "dark" ? "Dark" : "Light");

        SettingsService.Current.Theme = _currentTheme;
        SettingsService.Save();
    }

    private void UpdateUITexts()
    {
        Title = $"🌐 {_localization.GetText("title", _currentLanguage)}";
        txtHeaderTitle.Text = _localization.GetText("title", _currentLanguage);
        txtSubtitle.Text = _localization.GetText("subtitle", _currentLanguage);

        ipBadge.ToolTip = _localization.GetText("tip_ip_badge", _currentLanguage);
        btnClient.ToolTip = _localization.GetText("tip_client_btn", _currentLanguage);
        btnLanguage.ToolTip = _localization.GetText("tip_lang_btn", _currentLanguage);
        btnTheme.ToolTip = _localization.GetText("tip_theme_btn", _currentLanguage);
        btnUpdate.ToolTip = _localization.GetText("tip_update_btn", _currentLanguage);
        btnSettings.ToolTip = _localization.GetText("tip_settings_btn", _currentLanguage);
        btnTray.ToolTip = _localization.GetText("tip_tray_btn", _currentLanguage);

        btnClient.Content = _localization.GetText("btn_client", _currentLanguage);
        btnLanguage.Content = _currentLanguage == "es" ? "🌐 ES" : "🌐 EN";
        btnTheme.Content = ThemeService.GetThemeIcon(_currentTheme);
        btnUpdate.Content = "⬆️";
        btnSettings.Content = "⚙️";
        btnTray.Content = "🔽";

        btnShareAll.Content = _localization.GetText("btn_share_all", _currentLanguage);
        btnDiagnostics.Content = _localization.GetText("btn_diagnostics", _currentLanguage);
        btnRefresh.Content = _localization.GetText("btn_refresh", _currentLanguage);
        btnUninstall.Content = _localization.GetText("btn_uninstall", _currentLanguage);

        txtDevicesHeader.Text = _localization.GetText("header_devices", _currentLanguage);
        txtLogHeader.Text = _localization.GetText("header_log", _currentLanguage);
        btnClearLog.Content = _localization.GetText("btn_clear", _currentLanguage);

        colBusId.Header = _localization.GetText("col_busid", _currentLanguage);
        colVidPid.Header = _localization.GetText("col_vid_pid", _currentLanguage);
        colDeviceName.Header = _localization.GetText("col_device", _currentLanguage);
        colType.Header = _localization.GetText("col_type", _currentLanguage);
        colStatus.Header = _localization.GetText("col_status", _currentLanguage);
        colAction.Header = _localization.GetText("col_action", _currentLanguage);

        txtDeviceCount.Text = _localization.GetFormattedText("device_count", _currentLanguage, _deviceCollection.Count);

        if (_trayOpenItem != null)
            _trayOpenItem.Text = _localization.GetText("tray_open", _currentLanguage);
        if (_trayExitItem != null)
            _trayExitItem.Text = _localization.GetText("tray_exit", _currentLanguage);

        RenderLogs();
    }

    private void OnLogMessage(object? sender, string message)
    {
        if (message.Contains("sharing device", StringComparison.OrdinalIgnoreCase))
        {
            var busId = message.Split(' ').LastOrDefault()?.TrimEnd('.');
            AddLocalizedLog("log_sharing_device", busId ?? "");
        }
        else if (message.Contains("is now shared", StringComparison.OrdinalIgnoreCase))
        {
            var parts = message.Split(' ');
            var busId = parts.Length > 2 ? parts[2] : "";
            AddLocalizedLog("log_device_shared", busId);
        }
        else if (message.Contains("stopping share", StringComparison.OrdinalIgnoreCase))
        {
            var busId = message.Split(' ').LastOrDefault()?.TrimEnd('.');
            AddLocalizedLog("log_stopping_device", busId ?? "");
        }
        else if (message.Contains("is no longer shared", StringComparison.OrdinalIgnoreCase))
        {
            var parts = message.Split(' ');
            var busId = parts.Length > 2 ? parts[2] : "";
            AddLocalizedLog("log_device_stopped", busId);
        }
        else if (message.Contains("usbipd-win installed successfully", StringComparison.OrdinalIgnoreCase))
        {
            AddLocalizedLog("log_driver_installed_ok");
        }
        else if (message.Contains("usbipd-win uninstalled", StringComparison.OrdinalIgnoreCase))
        {
            AddLocalizedLog("log_driver_uninstalled");
        }
        else
        {
            Log(message);
        }
    }

    private void AddLocalizedLog(string key, params object[] args)
    {
        var entry = new ServerLogEntry(DateTime.Now, key, args, null);
        lock (_logHistory)
        {
            _logHistory.Add(entry);
            if (_logHistory.Count > 500) _logHistory.RemoveAt(0);
        }
        Dispatcher.Invoke(() =>
        {
            txtLog.AppendText($"[{entry.Timestamp:HH:mm:ss}] {_localization.GetFormattedText(key, _currentLanguage, args)}\n");
            txtLog.ScrollToEnd();
        });
    }

    private void Log(string message)
    {
        var entry = new ServerLogEntry(DateTime.Now, null, Array.Empty<object>(), message);
        lock (_logHistory)
        {
            _logHistory.Add(entry);
            if (_logHistory.Count > 500) _logHistory.RemoveAt(0);
        }
        Dispatcher.Invoke(() =>
        {
            txtLog.AppendText($"[{entry.Timestamp:HH:mm:ss}] {message}\n");
            txtLog.ScrollToEnd();
        });
    }

    private void RenderLogs()
    {
        Dispatcher.Invoke(() =>
        {
            txtLog.Clear();
            lock (_logHistory)
            {
                foreach (var entry in _logHistory)
                {
                    string text = entry.Key != null
                        ? _localization.GetFormattedText(entry.Key, _currentLanguage, entry.Args)
                        : (entry.RawMessage ?? string.Empty);
                    txtLog.AppendText($"[{entry.Timestamp:HH:mm:ss}] {text}\n");
                }
            }
            txtLog.ScrollToEnd();
        });
    }

    private void UpdateStatusBar(string message, Color color)
    {
        Dispatcher.Invoke(() =>
        {
            txtStatus.Text = message;
            txtStatus.Foreground = new SolidColorBrush(color);
        });
    }

    protected override void OnClosed(EventArgs e)
    {
        _refreshTimer.Stop();
        _usbipdService.Dispose();

        if (_notifyIcon != null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }

        base.OnClosed(e);
    }
}
