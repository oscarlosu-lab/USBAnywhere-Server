# Guía de Solución de Problemas — USBAnywhere Server

🌐 **Idioma / Language:** [English](TROUBLESHOOTING.md) | **Español**

---

## Problemas Comunes

### 1. La aplicación no se inicia

**Soluciones**:
1. Clic derecho en `USBAnywhere-Server.exe` → **Ejecutar como administrador**.
2. Revisar el Visor de eventos de Windows o la carpeta `%AppData%\USBAnywhere-Server\logs` (o `logs\` en modo Portable).

---

### 2. Falla la instalación de controladores

**Soluciones**:
1. Reiniciar Windows si hay actualizaciones pendientes del sistema operativo.
2. Instalación manual: Ejecutar `msiexec /i drivers\usbipd-win.msi` desde una consola de Administrador.

---

### 3. El cliente no detecta ni se conecta al servidor

**Soluciones**:
1. Abrir **⚙️ Configuración** en USBAnywhere Server y pulsar **🛡️ Configurar Firewall** para habilitar los puertos TCP 3240 (USB/IP) y UDP 3241 (Auto-Descubrimiento).
2. O ejecutar en PowerShell como Administrador:
   ```powershell
   New-NetFirewallRule -DisplayName "USBAnywhere Server (TCP 3240)" -Direction Inbound -Protocol TCP -LocalPort 3240 -Action Allow
   New-NetFirewallRule -DisplayName "USBAnywhere Discovery (UDP 3241)" -Direction Inbound -Protocol UDP -LocalPort 3241 -Action Allow
   ```
3. Verificar que el dispositivo aparezca en estado `Compartido` en la interfaz.

---

### 4. `dotnet test` finaliza con error `0xC0000142` (`STATUS_DLL_INIT_FAILED`)

**Síntomas**:
La ejecución de `dotnet test` se anula inmediatamente con el mensaje `El proceso del host de prueba finalizó con el siguiente error` sin ejecutar casos de prueba, y `testhost.exe` devuelve el código de salida `-1073741502` (`0xC0000142`).

**Causa**:
El Control de Integridad Obligatorio de Windows (MIC) o restricciones NTFS heredadas (`Nivel de Integridad Bajo` o reglas `Deny` residuales) impiden al cargador PE de Windows inicializar las DLLs de ejecución en el directorio de pruebas.

**Soluciones**:
1. Purgar cualquier regla de denegación (`Deny`) residual en el directorio del proyecto:
   ```cmd
   icacls <directorio_proyecto> /remove:d Todos /t /c
   ```
2. Restablecer el nivel de integridad del directorio a `Medio` (`Medium`):
   ```cmd
   icacls <directorio_proyecto> /setintegritylevel (OI)(CI)M /t /c
   ```
3. Limpiar cachés de compilación y reejecutar las pruebas:
   ```powershell
   dotnet clean
   dotnet test
   ```

---

## Soporte y Comunidad

- [Incidencias en GitHub (Issues)](https://github.com/oscarlosu-lab/USBAnywhere-Server/issues)
- [Repositorio del Cliente USBAnywhere](https://github.com/oscarlosu-lab/USBAnywhere)
- [Comunidad oficial en Reddit](https://reddit.com/r/UsbAnywhere)
