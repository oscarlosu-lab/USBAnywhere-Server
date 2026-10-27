/*
 * USBAnywhere Server - Application Entry Point
 * Copyright (c) 2025-2026 oscarlosu-lab
 * https://github.com/oscarlosu-lab/USBAnywhere-Server
 */

using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using USBAnywhere.Server.Services;

namespace USBAnywhere.Server;

/// <summary>
/// Main application class with single instance protection and robust exception handling.
/// </summary>
public partial class App : System.Windows.Application
{
    private static Mutex? _singleInstanceMutex;

    protected override void OnStartup(StartupEventArgs e)
    {
        const string mutexName = "Global\\USBAnywhere_Server_SingleInstance_Mutex";
        _singleInstanceMutex = new Mutex(true, mutexName, out bool createdNew);

        if (!createdNew)
        {
            string sysLang = LocalizationService.DetectSystemLanguage();
            string singleInstanceMsg = sysLang == "es"
                ? "USBAnywhere Server ya se encuentra en ejecución."
                : "USBAnywhere Server is already running.";
            System.Windows.MessageBox.Show(
                singleInstanceMsg,
                "USBAnywhere Server",
                System.Windows.MessageBoxButton.OK,
                System.Windows.MessageBoxImage.Information);
            Shutdown();
            return;
        }

        base.OnStartup(e);

        // Initialize logging first (before anything can fail)
        LogService.Initialize();
        LogService.Info("Application starting...");
        LogService.Info(PathService.GetDiagnosticReport());

        // Clean old logs (keep 7 days)
        LogService.CleanupOldLogs(7);

        // Hook global exception handlers
        SetupExceptionHandlers();

        LogService.Info("Startup complete");
    }

    private void SetupExceptionHandlers()
    {
        // UI thread exceptions
        DispatcherUnhandledException += OnDispatcherUnhandledException;

        // Non-UI thread exceptions
        AppDomain.CurrentDomain.UnhandledException += OnUnhandledException;

        // Task exceptions (async/await)
        TaskScheduler.UnobservedTaskException += OnUnobservedTaskException;

        LogService.Info("Exception handlers configured");
    }

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        LogService.Exception(e.Exception, "UI Thread");

        string sysLang = LocalizationService.DetectSystemLanguage();
        string title = sysLang == "es" ? "Error en USBAnywhere Server" : "USBAnywhere Server Error";
        string msg = sysLang == "es"
            ? $"Ocurrió un error inesperado:\n\n{e.Exception.Message}\n\nEl error ha sido registrado en el log."
            : $"An unexpected error occurred:\n\n{e.Exception.Message}\n\nThe error has been logged.";

        System.Windows.MessageBox.Show(
            msg,
            title,
            System.Windows.MessageBoxButton.OK,
            System.Windows.MessageBoxImage.Error);

        // Mark as handled to prevent crash (unless critical)
        e.Handled = true;
    }

    private void OnUnhandledException(object sender, UnhandledExceptionEventArgs e)
    {
        if (e.ExceptionObject is Exception ex)
        {
            LogService.Exception(ex, "AppDomain");
        }
        else
        {
            LogService.Error($"Unknown fatal error: {e.ExceptionObject}");
        }

        LogService.Error("Application terminating due to unhandled exception");
    }

    private void OnUnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
    {
        LogService.Exception(e.Exception, "Async Task");
        e.SetObserved();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_singleInstanceMutex != null)
        {
            try { _singleInstanceMutex.ReleaseMutex(); } catch { }
            _singleInstanceMutex.Dispose();
        }

        LogService.Info($"Application exiting with code: {e.ApplicationExitCode}");
        base.OnExit(e);
    }
}
