# VLC 9 — reproductor para iPad mini 1 (iOS 9, armv7)

Reproductor multimedia completo con el motor de **VLC (MobileVLCKit 3.7.4)**
para iPad de 32 bits con iOS 9. Incluye biblioteca por carpetas, gestos,
pistas de audio/subtítulos, listas, red/UPnP, historial, ajustes y reanudación.

- **Nombre visible:** VLC 9
- **Bundle:** `com.lofturb.vlc9` (convive con el VLC original)
- **Ejecutable:** `VLC9`
- **Objetivo:** armv7, iOS 9.0+, probado en iPad mini 1 (`iPad2,6`, iOS 9.3.6)
- **Firma:** ad-hoc con `ldid`; instalación con Filza + AppSync Unified
- **Compilación:** Theos en GitHub Actions (no hace falta Mac)

## Estructura

```
app/
  Makefile                 compilación, enlace y firma de MobileVLCKit
  control                  metadatos del paquete
  entitlements.plist       platform-application, no-sandbox, Media, llavero
  main.m                   punto de entrada
  AppDelegate.h/.m         ventana, pestañas e importación de archivos
  OVTheme.*                colores, iconos y utilidades de interfaz
  OVMediaItem.*            modelo de un vídeo, audio o URL
  OVLibrary.*              escaneo, índice, ajustes y posiciones
  OVThumbnailCache.*       miniaturas con VLCMediaThumbnailer
  OVMediaCell.*            celda de la biblioteca
  OVLibraryViewController.*    pestañas Vídeos y Música
  OVFolderBrowserViewController.*  explorador de carpetas y rutas
  OVPlayerViewController.*     reproductor VLC, gestos y pistas
  OVPlaylistViewController.*   lista de reproducción
  OVNetworkViewController.*    URLs, favoritos, historial y UPnP
  OVSettingsViewController.*   ajustes y mantenimiento
  Resources/               Info.plist, iconos y pantallas de arranque
  vendor/MobileVLCKit.framework  motor VLC (rebanada armv7)
tools/
  generar_recursos.py      genera iconos y arranque (sin Pillow)
  comprobar_fuentes.py     coherencia de Makefile, IDs, versión y entitlements
.github/
  workflows/build-ipa.yml  compila, verifica y publica el IPA
  notas-release.md         notas del Release
```

## Compilar en GitHub Actions

1. Crea un repositorio **vacío** en GitHub.
2. Sube el proyecto:

```powershell
git init
git add .
git commit -m "VLC 9 para iOS 9"
git branch -M main
git remote add origin https://github.com/TU-USUARIO/TU-REPO.git
git push -u origin main
```

3. El workflow **Construir IPA (iOS 9 / armv7)** se ejecuta solo. También puedes
   lanzarlo a mano con **Run workflow**.
4. Al terminar, descarga el `.ipa` desde **Releases** o **Artefactos**.

El workflow comprueba antes de publicar:

- que el ejecutable `VLC9` es armv7;
- que `Payload/VLC9.app/Frameworks/MobileVLCKit.framework/MobileVLCKit` existe,
  es armv7 y lleva firma ad-hoc;
- que el install name es `@rpath/MobileVLCKit.framework/MobileVLCKit`;
- que la app enlaza el framework por `@rpath`.

## Instalar en el iPad

Con el iPad conectado por USB y el jailbreak activo:

```powershell
python tools\verificar_ipa.py VLC9.ipa
python tools\afc_put.py VLC9.ipa /VLC9.ipa
```

Después, en el iPad: **Filza → /var/mobile/Media → VLC9.ipa → Instalar**.

> Requiere **AppSync Unified** para aceptar la firma ad-hoc. No borres el VLC
> original: VLC 9 usa otro bundle ID y se instala al lado.

## Uso rápido

- **Carpetas:** navega a cualquier ruta (por ejemplo `/var/mobile/Media`),
  pulsa el botón de carpeta para añadirla a la biblioteca. El análisis no copia
  ni modifica archivos.
- **Reproducir:** toca un archivo para reproducirlo con el resto de la carpeta
  como lista; usa “Reproducir esta carpeta” para incluir subcarpetas.
- **Gestos:** desliza en horizontal para buscar, en vertical izquierda para
  brillo y derecha para volumen; pellizca para zoom; doble toque a los lados
  para ±10 s.
- **Pistas y subtítulos:** botones *Audio* y *Subs*, o el menú `···`. Puedes
  cargar un `.srt` externo y ajustar el retardo.
- **Red:** introduce URLs HTTP/HTTPS/RTSP/RTMP/UDP/FTP/SMB y explora servidores
  UPnP/DLNA de la red local.
- **Ajustes:** reanudación, audio en segundo plano, aceleración por hardware,
  desentrelazado, codificación de subtítulos, caché de red y limpieza.

## Notas técnicas

- `TARGET = iphone:clang:9.3:9.0`, `ARCHS = armv7`, `GO_EASY_ON_ME = 1`.
- El framework se copia y se firma en `before-package::` antes de empaquetar.
- `MobileVLCKit` se enlaza con `-Fvendor` y `-Wl,-rpath,@executable_path/Frameworks`.
- La app usa `platform-application` y `no-sandbox` para leer carpetas fuera de
  su contenedor, y conserva los entitlements de llavero.

## Licencia y marcas

VLC es una marca de VideoLAN. Este proyecto es un reproductor independiente que
usa MobileVLCKit bajo la licencia **GNU LGPL 2.1**. No está afiliado a VideoLAN
ni a Apple.
