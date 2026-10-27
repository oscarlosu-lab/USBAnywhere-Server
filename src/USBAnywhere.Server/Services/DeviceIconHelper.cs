// ─────────────────────────────────────────────────────────────────────────────
// USBAnywhere Server - Device Icon Helper
// Copyright (c) 2025-2026 oscarlosu-lab - https://github.com/oscarlosu-lab/USBAnywhere-Server
// Licensed under GPL v3
// ─────────────────────────────────────────────────────────────────────────────

namespace USBAnywhere.Server.Services;

public static class DeviceIconHelper
{
    private static readonly Dictionary<int, string> KnownVendors = new()
    {
        { 0x046D, "🎮" }, // Logitech
        { 0x045E, "⌨️" }, // Microsoft
        { 0x1532, "🎮" }, // Razer
        { 0x1038, "🎮" }, // SteelSeries
        { 0x1B1C, "🎮" }, // Corsair
        { 0x054C, "🎮" }, // Sony
        { 0x057E, "🎮" }, // Nintendo
        { 0x0781, "💾" }, // SanDisk
        { 0x0951, "💾" }, // Kingston
        { 0x04E8, "📱" }, // Samsung
        { 0x05AC, "📱" }, // Apple
        { 0x12D1, "📱" }, // Huawei
        { 0x2717, "📱" }, // Xiaomi
        { 0x18D1, "📱" }, // Google
        { 0x04A9, "📷" }, // Canon
        { 0x04B0, "📷" }, // Nikon
        { 0x056A, "🖊️" }, // Wacom
        { 0x047F, "🎧" }, // Plantronics
        { 0x0B0E, "🎧" }, // Jabra
        { 0x0D8C, "🎤" }, // Blue Microphones
        { 0x19F7, "🎤" }, // RODE
        { 0x1235, "🎵" }, // Focusrite
        { 0x1397, "🎵" }, // Behringer
        { 0x1A86, "🔌" }, // QinHeng CH340
    };

    public static string GetIcon(int vendorId, int productId, string description)
    {
        if (KnownVendors.TryGetValue(vendorId, out var vendorIcon))
        {
            return vendorIcon;
        }

        var descLower = (description ?? "").ToLowerInvariant();

        if (descLower.Contains("keyboard") || descLower.Contains("teclado"))
            return "⌨️";
        if (descLower.Contains("mouse") || descLower.Contains("ratón") || descLower.Contains("raton"))
            return "🖱️";
        if (descLower.Contains("gamepad") || descLower.Contains("controller") || descLower.Contains("joystick"))
            return "🎮";
        if (descLower.Contains("headset") || descLower.Contains("headphone") || descLower.Contains("auricular"))
            return "🎧";
        if (descLower.Contains("microphone") || descLower.Contains("micrófono") || descLower.Contains("microfono"))
            return "🎤";
        if (descLower.Contains("webcam") || descLower.Contains("camera") || descLower.Contains("cámara"))
            return "📹";
        if (descLower.Contains("storage") || descLower.Contains("flash") || descLower.Contains("usb drive") || descLower.Contains("pendrive") || descLower.Contains("masivo"))
            return "💾";
        if (descLower.Contains("hub"))
            return "🔌";
        if (descLower.Contains("bluetooth"))
            return "📶";
        if (descLower.Contains("printer") || descLower.Contains("impresora"))
            return "🖨️";
        if (descLower.Contains("phone") || descLower.Contains("android") || descLower.Contains("móvil"))
            return "📱";
        if (descLower.Contains("tablet") || descLower.Contains("ipad"))
            return "📱";
        if (descLower.Contains("audio") || descLower.Contains("sound") || descLower.Contains("sonido"))
            return "🔊";
        if (descLower.Contains("network") || descLower.Contains("ethernet") || descLower.Contains("wifi"))
            return "🌐";

        return "🔌";
    }

    public static string GetTypeName(int vendorId, int productId, string description)
    {
        return GetLocalizedTypeName(vendorId, productId, description, "en");
    }

    public static string GetLocalizedTypeName(int vendorId, int productId, string description, string language = "en")
    {
        bool isEs = string.Equals(language, "es", StringComparison.OrdinalIgnoreCase);
        var descLower = (description ?? "").ToLowerInvariant();

        if (descLower.Contains("keyboard") || descLower.Contains("teclado")) return isEs ? "Teclado" : "Keyboard";
        if (descLower.Contains("mouse") || descLower.Contains("ratón") || descLower.Contains("raton")) return isEs ? "Ratón" : "Mouse";
        if (descLower.Contains("gamepad") || descLower.Contains("controller")) return isEs ? "Mando / Juego" : "Game Controller";
        if (descLower.Contains("headset") || descLower.Contains("headphone")) return isEs ? "Auriculares" : "Headset";
        if (descLower.Contains("microphone") || descLower.Contains("micrófono")) return isEs ? "Micrófono" : "Microphone";
        if (descLower.Contains("webcam") || descLower.Contains("camera") || descLower.Contains("cámara")) return isEs ? "Cámara / Webcam" : "Camera";
        if (descLower.Contains("storage") || descLower.Contains("flash") || descLower.Contains("drive") || descLower.Contains("masivo")) return isEs ? "Almacenamiento" : "Storage";
        if (descLower.Contains("hub")) return isEs ? "Hub USB" : "USB Hub";
        if (descLower.Contains("bluetooth")) return "Bluetooth";
        if (descLower.Contains("printer") || descLower.Contains("impresora")) return isEs ? "Impresora" : "Printer";
        if (descLower.Contains("phone") || descLower.Contains("android")) return isEs ? "Móvil / Tablet" : "Mobile Device";
        if (descLower.Contains("audio") || descLower.Contains("sound") || descLower.Contains("sonido")) return isEs ? "Dispositivo de Audio" : "Audio Device";
        if (descLower.Contains("serial") || descLower.Contains("ch340") || descLower.Contains("cp210") || descLower.Contains("ftdi")) return isEs ? "Serie / UART" : "Serial / UART";

        return isEs ? "Dispositivo USB" : "USB Device";
    }
}
