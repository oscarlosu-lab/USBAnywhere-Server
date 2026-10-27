# USBAnywhere Server - Manual de Usuario

🌐 **Idioma:** [English](USAGE_EN.md) | Español

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Instalación](#instalación)
3. [Primer Arranque](#primer-arranque)
4. [Compartir Dispositivos USB](#compartir-dispositivos-usb)
5. [Conectar desde Cliente](#conectar-desde-cliente)
6. [Solución de Problemas](#solución-de-problemas)
7. [Desinstalación](#desinstalación)

---

## Introducción

**USBAnywhere Server** te permite compartir dispositivos USB conectados a tu PC Windows a través de la red local. Otros ordenadores con **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere)** pueden conectarse a estos dispositivos como si estuvieran enchufados directamente.

### Casos de Uso

- **Impresoras 3D y Grabadoras Láser**: Controla tu máquina desde cualquier PC de la red
- **Dongles de Licencia**: Comparte llaves USB de software
- **Escáneres y Webcams**: Úsalos desde cualquier estación de trabajo
- **Placas de Desarrollo y Serial/UART (CH340, Arduino, ESP32)**: Programa y depura remotamente

---

## Instalación

### Requisitos
- Windows 10/11 (64-bit)
- Permisos de Administrador
- Conexión de red local (Puerto TCP 3240)

### Pasos

1. Descarga la última versión desde [GitHub Releases](https://github.com/oscarlosu-lab/USBAnywhere-Server/releases/latest)
2. Ejecuta el instalador `USBAnywhere-Server_Setup_v3.0.0.exe` o extrae el archivo `USBAnywhere-Server-v3.0.0-x64-Portable.zip`

---

## Primer Arranque

1. Ejecuta `USBAnywhere-Server.exe` (solicitará permisos de Administrador automáticamente)
2. Si `usbipd-win` no está instalado, la aplicación lo detectará y lo instalará automáticamente desde el paquete MSI incluido.

---

## Compartir Dispositivos USB

### Compartir un Dispositivo o Compartir Todo

1. Haz clic en **📤 Compartir** junto al dispositivo que quieras exportar, o pulsa **⚡ Compartir Todo** en la barra superior para compartir todos los periféricos compatibles con un solo clic.
2. El estado cambiará a `Shared` (o `Attached` cuando un cliente esté conectado).
3. Haz clic en la insignia verde **IP** (`IP: x.x.x.x:3240`) de la cabecera para copiar la IP del servidor al portapapeles.

### Dejar de Compartir

1. Haz clic en **🚫 Detener** en el dispositivo compartido para devolverlo al uso exclusivo local.

---

## Conectar desde Cliente

### Usando USBAnywhere Client (Recomendado)

1. Descarga **[USBAnywhere Client](https://github.com/oscarlosu-lab/USBAnywhere/releases/latest)** (o pulsa **🔗 Cliente USBAnywhere** en la barra superior)
2. Pega la dirección IP de tu servidor
3. Haz clic en **Escanear** y conéctate a tus dispositivos USB.

---

## Solución de Problemas

Consulta la [Guía de Solución de Problemas](TROUBLESHOOTING.md) o entra en **⚙️ Ajustes → 🛡️ Configure Firewall** para abrir el puerto TCP 3240 en el Firewall de Windows.

---

## Desinstalación

1. Abre **USBAnywhere Server**
2. Haz clic en **🗑️ Desinstalar Driver** si deseas eliminar también el controlador `usbipd-win`
3. Desinstala **USBAnywhere Server** desde Configuración de Windows (o borra la carpeta si usas la versión Portable).
