namespace USBAnywhere.Server.Services;

/// <summary>
/// Localization service - Comprehensive bilingual translation dictionaries (ES/EN) for USBAnywhere Server v3.0.0
/// </summary>
public class LocalizationService
{
    private readonly Dictionary<string, Dictionary<string, string>> _translations;

    public LocalizationService()
    {
        _translations = new Dictionary<string, Dictionary<string, string>>
        {
            ["es"] = new Dictionary<string, string>
            {
                // Window & Header
                ["title"] = "USBAnywhere Server",
                ["subtitle"] = "Servidor USB/IP para Windows — Ecosistema USBAnywhere v3.0",
                ["tip_ip_badge"] = "Haz clic para copiar la IP del servidor para el cliente USBAnywhere",
                ["tip_client_btn"] = "Abrir Cliente USBAnywhere o copiar IP del servidor",
                ["tip_lang_btn"] = "Cambiar idioma (ES/EN)",
                ["tip_theme_btn"] = "Cambiar tema (Oscuro/Claro)",
                ["tip_update_btn"] = "Buscar actualizaciones",
                ["tip_settings_btn"] = "Configuración",
                ["tip_tray_btn"] = "Minimizar a la bandeja del sistema",

                // Buttons
                ["btn_update"] = "⬆️ Actualizar",
                ["btn_settings"] = "⚙️ Ajustes",
                ["btn_tray"] = "🔽 Minimizar",
                ["btn_diagnostics"] = "🔍 Diagnóstico",
                ["btn_refresh"] = "🔄 Actualizar",
                ["btn_share_all"] = "⚡ Compartir Todo",
                ["btn_client"] = "🔗 Cliente USBAnywhere",
                ["btn_uninstall"] = "🗑️ Desinstalar Driver",
                ["btn_share"] = "📤 Compartir",
                ["btn_stop"] = "🚫 Detener",
                ["btn_clear"] = "Limpiar",

                // Headers & Columns
                ["header_devices"] = "📱 Dispositivos USB Locales",
                ["header_log"] = "📋 Registro de Actividad",
                ["col_icon"] = "🔌",
                ["col_type"] = "Tipo",
                ["col_busid"] = "Bus ID",
                ["col_device"] = "Nombre del Dispositivo",
                ["col_vid_pid"] = "VID:PID",
                ["col_status"] = "Estado",
                ["col_action"] = "Acción",

                // Device Types
                ["type_keyboard"] = "Teclado",
                ["type_mouse"] = "Ratón",
                ["type_gamepad"] = "Mando / Juego",
                ["type_headset"] = "Auriculares",
                ["type_microphone"] = "Micrófono",
                ["type_camera"] = "Cámara / Webcam",
                ["type_storage"] = "Almacenamiento",
                ["type_hub"] = "Hub USB",
                ["type_bluetooth"] = "Bluetooth",
                ["type_printer"] = "Impresora",
                ["type_mobile"] = "Móvil / Tablet",
                ["type_audio"] = "Dispositivo de Audio",
                ["type_serial"] = "Serie / UART",
                ["type_device"] = "Dispositivo USB",

                // Status
                ["status_checking"] = "Comprobando servicio...",
                ["status_shared"] = "Compartido",
                ["status_shared_forced"] = "Compartido (forzado)",
                ["status_attached"] = "Conectado (Cliente)",
                ["status_not_shared"] = "No compartido",
                ["status_ready"] = "Listo",
                ["status_running"] = "Servidor activo en puerto 3240 (usbipd corriendo)",
                ["status_not_available"] = "usbipd-win no disponible",
                ["device_count"] = "{0} dispositivo(s)",

                // Badges
                ["badge_admin"] = "ADMIN",
                ["badge_user"] = "USUARIO",
                ["badge_portable"] = "PORTABLE",
                ["badge_installed"] = "INSTALADO",

                // Log Messages
                ["log_server_started"] = "🌐 USBAnywhere Server v3.0.0 — Servidor USB/IP para Windows",
                ["log_driver_detected"] = "✅ usbipd-win detectado y listo",
                ["log_driver_not_installed"] = "⚠️ usbipd-win no está instalado",
                ["log_driver_installing"] = "📦 Instalando driver usbipd-win...",
                ["log_driver_installed_ok"] = "✅ Driver usbipd-win instalado exitosamente!",
                ["log_driver_install_fail"] = "❌ Error al instalar usbipd-win. Ejecute como Administrador.",
                ["log_driver_skipped"] = "ℹ️ Instalación del driver omitida por el usuario",
                ["log_driver_unavailable_warn"] = "⚠️ La función de compartir USB no estará disponible sin el driver",
                ["log_service_reinitialized"] = "🔄 Servicio re-inicializado",
                ["log_list_refreshed"] = "🔄 Lista de dispositivos actualizada",
                ["log_refresh_error"] = "⚠️ Error al actualizar lista: {0}",
                ["log_sharing_device"] = "📤 Compartiendo dispositivo {0}...",
                ["log_device_shared"] = "✅ Dispositivo {0} compartido exitosamente",
                ["log_stopping_device"] = "🚫 Deteniendo compartición de {0}...",
                ["log_device_stopped"] = "✅ Dispositivo {0} detenido",
                ["log_invalid_busid"] = "❌ Formato de Bus ID inválido: {0}",
                ["log_autobind_trigger"] = "⚡ Auto-compartiendo dispositivo guardado: {0} ({1})",
                ["log_share_all_all_done"] = "ℹ️ Todos los dispositivos compatibles ya están compartidos.",
                ["log_share_all_result"] = "⚡ Compartidos {0}/{1} dispositivos.",
                ["log_ip_copied"] = "📋 IP del servidor copiada al portapapeles: {0} (puerto TCP 3240)",
                ["log_client_launched"] = "🔗 Cliente USBAnywhere iniciado ({0}) — IP {1} copiada al portapapeles.",
                ["log_uninstalling_driver"] = "🗑️ Desinstalando driver usbipd-win...",
                ["log_driver_uninstalled"] = "✅ Driver usbipd-win desinstalado.",
                ["log_checking_updates"] = "🔍 Buscando actualizaciones...",
                ["log_update_status"] = "📊 Versión actual: v{0} | Última: v{1}",
                ["log_update_available"] = "⬆️ Nueva versión disponible: v{0}",
                ["log_update_downloading"] = "📥 Descargando actualización...",
                ["log_update_failed"] = "❌ Error en actualización: {0}",
                ["log_update_latest"] = "✅ Tienes la última versión instalada (v{0})",
                ["log_lang_changed"] = "🌐 Idioma cambiado a: Español",
                ["log_theme_changed"] = "🎨 Tema cambiado a: {0}",
                ["log_settings_saved"] = "⚙️ Configuración guardada",
                ["log_diagnostics_shown"] = "🔍 Diagnóstico mostrado",

                // Update Prompts
                ["update_available_title"] = "Actualización Disponible",
                ["update_available_prompt"] = "Nueva versión disponible: v{0}\n\n{1}\n\n¿Desea descargar e instalar la actualización ahora?",
                ["update_downloading_status"] = "Descargando actualización...",
                ["update_checking_status"] = "Buscando actualizaciones...",
                ["update_error_status"] = "Error: {0}",

                // Driver Prompts
                ["driver_missing_title"] = "Driver no encontrado",
                ["driver_missing_prompt"] = "El driver usbipd-win no está instalado.\n\nEste componente es necesario para compartir dispositivos USB por red con clientes USBAnywhere.\n\n¿Desea instalar el driver ahora?",
                ["driver_uninstall_title"] = "Desinstalar usbipd-win",
                ["driver_uninstall_prompt"] = "Esto desinstalará el driver usbipd-win y detendrá la compartición USB/IP.\n\n¿Está seguro?",

                // Client Launch Prompt
                ["client_prompt_title"] = "Ecosistema USBAnywhere",
                ["client_prompt_msg"] = "IP de este servidor copiada al portapapeles: {0} (Puerto TCP 3240).\n\nConéctese desde USBAnywhere Client introduciendo esta IP en la pestaña de conexión.\n\n¿Desea abrir la página oficial de USBAnywhere Client en GitHub?",

                // Tray
                ["tray_open"] = "Abrir USBAnywhere Server",
                ["tray_exit"] = "Salir",
                ["tray_minimized"] = "Ejecutándose en segundo plano. Doble clic para restaurar.",

                // Settings Window
                ["settings_title"] = "⚙️ Ajustes - USBAnywhere Server",
                ["settings_subtitle"] = "Configuración y preferencias de USBAnywhere Server",
                ["sec_general"] = "🏠 GENERAL",
                ["chk_start_windows"] = "Iniciar con Windows",
                ["chk_start_minimized"] = "Iniciar minimizado en la bandeja del sistema",
                ["chk_show_notifications"] = "Mostrar notificaciones emergentes",
                ["chk_check_updates"] = "Buscar actualizaciones al iniciar",
                ["sec_autobind"] = "🔗 AUTO-BIND (Compartición USB Persistente)",
                ["chk_autobind"] = "Activar Auto-Bind para dispositivos compartidos",
                ["desc_autobind"] = "Cuando está activado, los dispositivos que compartas se volverán a compartir automáticamente al conectarlos.",
                ["sec_security"] = "🔒 SEGURIDAD",
                ["chk_whitelist"] = "Activar lista blanca de IP",
                ["chk_require_pin"] = "Requerir PIN antes de compartir dispositivos",
                ["sec_network"] = "🌐 RED (Puerto TCP 3240)",
                ["btn_firewall"] = "🛡️ Configurar Firewall",
                ["fw_configured"] = "✅ Configurado (TCP 3240)",
                ["fw_not_configured"] = "⚠️ No configurado",
                ["sec_advanced"] = "⚙️ AVANZADO",
                ["lbl_refresh_interval"] = "Intervalo de refresco:",
                ["lbl_seconds"] = "segundos",
                ["sec_backup"] = "💾 COPIA DE SEGURIDAD",
                ["btn_export"] = "📤 Exportar",
                ["btn_import"] = "📥 Importar",
                ["btn_reset"] = "Restablecer por defecto",
                ["btn_cancel"] = "Cancelar",
                ["btn_save"] = "💾 Guardar",

                // Settings Dialogs
                ["fw_already_title"] = "Firewall ya configurado",
                ["fw_already_prompt"] = "La regla del Firewall ya está configurada.\n\n¿Desea ELIMINAR la regla?",
                ["fw_confirm_title"] = "Configurar Firewall",
                ["fw_confirm_prompt"] = "Esto creará una regla en el Firewall de Windows para permitir conexiones entrantes de USBAnywhere en el puerto TCP 3240.\n\n¿Desea continuar?",
                ["fw_success_title"] = "Firewall Configurado",
                ["fw_success_msg"] = "✅ Regla de Firewall creada exitosamente!\n\nEl puerto TCP 3240 está abierto para conexiones USBAnywhere.",
                ["fw_error_title"] = "Error",
                ["fw_error_msg"] = "❌ No se pudo crear la regla de Firewall.\n\nAsegúrese de ejecutar como Administrador.",
                ["export_title"] = "Exportar Configuración",
                ["export_success_title"] = "Exportación Exitosa",
                ["export_success_msg"] = "Configuración exportada a:\n{0}",
                ["import_title"] = "Importar Configuración",
                ["import_success_title"] = "Importación Exitosa",
                ["import_success_msg"] = "¡Configuración importada exitosamente!",
                ["import_fail_title"] = "Fallo de Importación",
                ["import_fail_msg"] = "No se pudo importar la configuración. Compruebe el formato del archivo.",
                ["reset_title"] = "Restablecer Configuración",
                ["reset_prompt"] = "¿Está seguro de que desea restablecer todos los ajustes a los valores predeterminados?",

                // Diagnostics
                ["diag_title"] = "Diagnóstico de USBAnywhere Server",
                ["diag_server_ip"] = "IP del Servidor: {0}:3240",
                ["diag_current_log"] = "Log actual: {0}",

                // App Startup
                ["app_already_running"] = "USBAnywhere Server ya se encuentra en ejecución.",
                ["app_unexpected_error"] = "Ocurrió un error inesperado:\n\n{0}\n\nEl error ha sido registrado."
            },

            ["en"] = new Dictionary<string, string>
            {
                // Window & Header
                ["title"] = "USBAnywhere Server",
                ["subtitle"] = "Windows USB/IP Server — USBAnywhere v3.0 Ecosystem",
                ["tip_ip_badge"] = "Click to copy Server IP for USBAnywhere Client",
                ["tip_client_btn"] = "Open USBAnywhere Client or copy Server IP",
                ["tip_lang_btn"] = "Switch language (ES/EN)",
                ["tip_theme_btn"] = "Switch theme (Dark/Light)",
                ["tip_update_btn"] = "Check for Updates",
                ["tip_settings_btn"] = "Settings",
                ["tip_tray_btn"] = "Minimize to System Tray",

                // Buttons
                ["btn_update"] = "⬆️ Update",
                ["btn_settings"] = "⚙️ Settings",
                ["btn_tray"] = "🔽 To Tray",
                ["btn_diagnostics"] = "🔍 Diagnostics",
                ["btn_refresh"] = "🔄 Refresh",
                ["btn_share_all"] = "⚡ Share All",
                ["btn_client"] = "🔗 USBAnywhere Client",
                ["btn_uninstall"] = "🗑️ Uninstall Driver",
                ["btn_share"] = "📤 Share",
                ["btn_stop"] = "🚫 Stop",
                ["btn_clear"] = "Clear",

                // Headers & Columns
                ["header_devices"] = "📱 Local USB Devices",
                ["header_log"] = "📋 Activity Log",
                ["col_icon"] = "🔌",
                ["col_type"] = "Type",
                ["col_busid"] = "Bus ID",
                ["col_device"] = "Device Name",
                ["col_vid_pid"] = "VID:PID",
                ["col_status"] = "Status",
                ["col_action"] = "Action",

                // Device Types
                ["type_keyboard"] = "Keyboard",
                ["type_mouse"] = "Mouse",
                ["type_gamepad"] = "Gamepad / Controller",
                ["type_headset"] = "Headset",
                ["type_microphone"] = "Microphone",
                ["type_camera"] = "Camera / Webcam",
                ["type_storage"] = "Storage",
                ["type_hub"] = "USB Hub",
                ["type_bluetooth"] = "Bluetooth",
                ["type_printer"] = "Printer",
                ["type_mobile"] = "Mobile / Tablet",
                ["type_audio"] = "Audio Device",
                ["type_serial"] = "Serial / UART",
                ["type_device"] = "USB Device",

                // Status
                ["status_checking"] = "Checking service...",
                ["status_shared"] = "Shared",
                ["status_shared_forced"] = "Shared (forced)",
                ["status_attached"] = "Attached (Client)",
                ["status_not_shared"] = "Not shared",
                ["status_ready"] = "Ready",
                ["status_running"] = "Server running on port 3240 (usbipd active)",
                ["status_not_available"] = "usbipd-win not available",
                ["device_count"] = "{0} device(s)",

                // Badges
                ["badge_admin"] = "ADMIN",
                ["badge_user"] = "USER",
                ["badge_portable"] = "PORTABLE",
                ["badge_installed"] = "INSTALLED",

                // Log Messages
                ["log_server_started"] = "🌐 USBAnywhere Server v3.0.0 — Windows USB/IP Server",
                ["log_driver_detected"] = "✅ usbipd-win detected and ready",
                ["log_driver_not_installed"] = "⚠️ usbipd-win is not installed",
                ["log_driver_installing"] = "📦 Installing usbipd-win driver...",
                ["log_driver_installed_ok"] = "✅ usbipd-win installed successfully!",
                ["log_driver_install_fail"] = "❌ Failed to install usbipd-win. Please run as Administrator.",
                ["log_driver_skipped"] = "ℹ️ Driver installation skipped by user",
                ["log_driver_unavailable_warn"] = "⚠️ USB sharing functionality will not be available without driver",
                ["log_service_reinitialized"] = "🔄 Service reinitialized",
                ["log_list_refreshed"] = "🔄 Device list refreshed",
                ["log_refresh_error"] = "⚠️ Error refreshing list: {0}",
                ["log_sharing_device"] = "📤 Sharing device {0}...",
                ["log_device_shared"] = "✅ Device {0} shared successfully",
                ["log_stopping_device"] = "🚫 Stopping share for {0}...",
                ["log_device_stopped"] = "✅ Device {0} stopped",
                ["log_invalid_busid"] = "❌ Invalid Bus ID format: {0}",
                ["log_autobind_trigger"] = "⚡ Auto-binding saved device: {0} ({1})",
                ["log_share_all_all_done"] = "ℹ️ All eligible devices are already shared.",
                ["log_share_all_result"] = "⚡ Shared {0}/{1} devices.",
                ["log_ip_copied"] = "📋 Server IP copied to clipboard: {0} (TCP port 3240)",
                ["log_client_launched"] = "🔗 USBAnywhere Client launched ({0}) — Server IP {1} copied to clipboard.",
                ["log_uninstalling_driver"] = "🗑️ Uninstalling usbipd-win driver...",
                ["log_driver_uninstalled"] = "✅ usbipd-win driver uninstalled.",
                ["log_checking_updates"] = "🔍 Checking for updates...",
                ["log_update_status"] = "📊 Current version: v{0} | Latest: v{1}",
                ["log_update_available"] = "⬆️ Update available: v{0}",
                ["log_update_downloading"] = "📥 Downloading update...",
                ["log_update_failed"] = "❌ Update failed: {0}",
                ["log_update_latest"] = "✅ You have the latest version (v{0})",
                ["log_lang_changed"] = "🌐 Language changed to: English",
                ["log_theme_changed"] = "🎨 Theme changed to: {0}",
                ["log_settings_saved"] = "⚙️ Settings saved",
                ["log_diagnostics_shown"] = "🔍 Diagnostics displayed",

                // Update Prompts
                ["update_available_title"] = "Update Available",
                ["update_available_prompt"] = "New version available: v{0}\n\n{1}\n\nDo you want to download and install the update now?",
                ["update_downloading_status"] = "Downloading update...",
                ["update_checking_status"] = "Checking for updates...",
                ["update_error_status"] = "Error: {0}",

                // Driver Prompts
                ["driver_missing_title"] = "Driver Not Found",
                ["driver_missing_prompt"] = "The usbipd-win driver is not installed.\n\nThis component is required to share USB devices over the network with USBAnywhere clients.\n\nWould you like to install the driver now?",
                ["driver_uninstall_title"] = "Uninstall usbipd-win",
                ["driver_uninstall_prompt"] = "This will uninstall the usbipd-win driver and stop USB/IP sharing.\n\nAre you sure?",

                // Client Launch Prompt
                ["client_prompt_title"] = "USBAnywhere Ecosystem",
                ["client_prompt_msg"] = "This server's IP has been copied to your clipboard: {0} (TCP Port 3240).\n\nConnect from USBAnywhere Client by entering this IP.\n\nWould you like to open the official USBAnywhere Client GitHub page?",

                // Tray
                ["tray_open"] = "Open USBAnywhere Server",
                ["tray_exit"] = "Exit",
                ["tray_minimized"] = "Running in background. Double-click to restore.",

                // Settings Window
                ["settings_title"] = "⚙️ Settings - USBAnywhere Server",
                ["settings_subtitle"] = "Configure USBAnywhere Server preferences",
                ["sec_general"] = "🏠 GENERAL",
                ["chk_start_windows"] = "Start with Windows",
                ["chk_start_minimized"] = "Start minimized to System Tray",
                ["chk_show_notifications"] = "Show balloon notifications",
                ["chk_check_updates"] = "Check for updates on startup",
                ["sec_autobind"] = "🔗 AUTO-BIND (Persistent USB Sharing)",
                ["chk_autobind"] = "Enable Auto-Bind for shared devices",
                ["desc_autobind"] = "When enabled, devices you share will automatically be re-shared whenever they are plugged in.",
                ["sec_security"] = "🔒 SECURITY",
                ["chk_whitelist"] = "Enable IP Whitelist",
                ["chk_require_pin"] = "Require PIN before sharing devices",
                ["sec_network"] = "🌐 NETWORK (TCP Port 3240)",
                ["btn_firewall"] = "🛡️ Configure Firewall",
                ["fw_configured"] = "✅ Configured (TCP 3240)",
                ["fw_not_configured"] = "⚠️ Not configured",
                ["sec_advanced"] = "⚙️ ADVANCED",
                ["lbl_refresh_interval"] = "Refresh interval:",
                ["lbl_seconds"] = "seconds",
                ["sec_backup"] = "💾 BACKUP",
                ["btn_export"] = "📤 Export",
                ["btn_import"] = "📥 Import",
                ["btn_reset"] = "Reset to Defaults",
                ["btn_cancel"] = "Cancel",
                ["btn_save"] = "💾 Save",

                // Settings Dialogs
                ["fw_already_title"] = "Firewall Already Configured",
                ["fw_already_prompt"] = "Firewall rule is already configured.\n\nDo you want to REMOVE the rule?",
                ["fw_confirm_title"] = "Configure Firewall",
                ["fw_confirm_prompt"] = "This will create a Windows Firewall rule to allow incoming USBAnywhere connections on TCP port 3240.\n\nDo you want to proceed?",
                ["fw_success_title"] = "Firewall Configured",
                ["fw_success_msg"] = "✅ Firewall rule created successfully!\n\nPort 3240 is now open for USBAnywhere connections.",
                ["fw_error_title"] = "Error",
                ["fw_error_msg"] = "❌ Failed to create firewall rule.\n\nMake sure you're running as Administrator.",
                ["export_title"] = "Export Settings",
                ["export_success_title"] = "Export Successful",
                ["export_success_msg"] = "Settings exported to:\n{0}",
                ["import_title"] = "Import Settings",
                ["import_success_title"] = "Import Successful",
                ["import_success_msg"] = "Settings imported successfully!",
                ["import_fail_title"] = "Import Failed",
                ["import_fail_msg"] = "Failed to import settings. Check the file format.",
                ["reset_title"] = "Reset Settings",
                ["reset_prompt"] = "Are you sure you want to reset all settings to defaults?",

                // Diagnostics
                ["diag_title"] = "USBAnywhere Server Diagnostics",
                ["diag_server_ip"] = "Server IP: {0}:3240",
                ["diag_current_log"] = "Current Log: {0}",

                // App Startup
                ["app_already_running"] = "USBAnywhere Server is already running.",
                ["app_unexpected_error"] = "An unexpected error occurred:\n\n{0}\n\nThe error has been logged."
            }
        };
    }

    public string GetText(string key, string language = "en")
    {
        if (_translations.TryGetValue(language, out var langDict) && langDict.TryGetValue(key, out var text))
            return text;

        if (_translations.TryGetValue("en", out var enDict) && enDict.TryGetValue(key, out var enText))
            return enText;

        return key;
    }

    public string GetText(string key, string language, params object[] args)
    {
        var text = GetText(key, language);
        try
        {
            return string.Format(text, args);
        }
        catch
        {
            return text;
        }
    }

    public string GetFormattedText(string key, string language, params object[] args) =>
        GetText(key, language, args);

    public static string DetectSystemLanguage()
    {
        var saved = SettingsService.Current.Language;
        if (!string.IsNullOrEmpty(saved) && (saved == "es" || saved == "en"))
            return saved;

        var systemLang = System.Globalization.CultureInfo.CurrentCulture.TwoLetterISOLanguageName;
        return systemLang == "es" ? "es" : "en";
    }
}
