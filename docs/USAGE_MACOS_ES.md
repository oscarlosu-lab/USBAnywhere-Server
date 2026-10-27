# 🍎 USBAnywhere Server para macOS — Guía de Usuario

Español | [English](USAGE_MACOS_EN.md)

---

## Descripción General

**USBAnywhere Server para macOS** permite a cualquier Mac (con procesador Apple Silicon M1/M2/M3/M4 o Intel) compartir dispositivos USB locales (como **joysticks de vuelo, volantes simracing, mandos/gamepads, pianos/instrumentos MIDI, webcams o dongles**) a través de la red hacia cualquier ordenador Windows con el cliente **USBAnywhere Client**.

Opera como un servidor nativo USB/IP a la escucha en el puerto estándar TCP `3240`.

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support%20Project-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white)](https://ko-fi.com/oscarlosu)

---

## ⚡ Instalación en 1 Clic

Abre la **Terminal** en tu Mac y ejecuta:

```bash
curl -fsSL https://raw.githubusercontent.com/oscarlosu-lab/USBAnywhere-Server/main/scripts/install-server-mac.sh | sudo bash
```

El instalador automáticamente:
1. Detecta la arquitectura (`arm64` Apple Silicon o `x86_64` Intel).
2. Instala el binario universal en `/usr/local/bin/usbanywhere-server-mac`.
3. Configura y activa `/Library/LaunchDaemons/com.usbanywhere.server.plist` para iniciar en segundo plano al arrancar el sistema.
4. Exporta los periféricos USB conectados (excluyendo hubs).

---

## 🚀 Uso Rápido

### 1. Ver dispositivos USB conectados
Para listar el hardware reconocido y sus identificadores de bus (Bus ID):

```bash
usbanywhere-server-mac list
```

Ejemplo de salida:
```text
Discovered USB Devices:
  [1-1] Logitech Inc. - Extreme 3D Pro (046D:C215) - 🟡 SHARED
  [1-2] Sony Interactive - DualSense Wireless Controller (054C:0CE6) - 🟡 SHARED
```

### 2. Compartir / Desasociar manualmente
Si deseas controlar qué periféricos específicos compartir:

```bash
# Compartir un periférico específico:
usbanywhere-server-mac bind 1-1

# Dejar de compartir:
usbanywhere-server-mac unbind 1-1
```

### 3. Conectar desde el PC con Windows
1. Abre **USBAnywhere Client** en tu PC Windows.
2. Introduce la dirección IP de tu Mac (ej. `192.168.1.50`).
3. Haz clic en **Listar / List Devices** (o pulsa la tecla **Enter**).
4. Selecciona tu joystick o mando y pulsa **Conectar**.
5. ¡Windows reconocerá el dispositivo de inmediato a través de sus controladores estándar PnP!

---

## 🔧 Gestión del Servicio en Segundo Plano

### Ver estado del servicio
```bash
sudo launchctl list | grep com.usbanywhere.server
```

### Consultar registros en tiempo real (logs)
```bash
tail -f /var/log/usbanywhere-server.log
```

### Detener servicio
```bash
sudo launchctl unload -w /Library/LaunchDaemons/com.usbanywhere.server.plist
```

### Iniciar servicio
```bash
sudo launchctl load -w /Library/LaunchDaemons/com.usbanywhere.server.plist
```

### Desinstalación
```bash
sudo usbanywhere-server-mac uninstall-service
```
O ejecutando el script desinstalador:
```bash
curl -fsSL https://raw.githubusercontent.com/oscarlosu-lab/USBAnywhere-Server/main/scripts/uninstall-server-mac.sh | sudo bash
```

---

## 🛠️ Compilación desde el Código Fuente

Requisitos:
- macOS 12 Monterey o posterior
- Swift 5.9+ / Herramientas de línea de comandos de Xcode (`xcode-select --install`)

```bash
cd src/USBAnywhere.Server.Mac
swift build -c release
cp .build/release/usbanywhere-server-mac /usr/local/bin/
```
