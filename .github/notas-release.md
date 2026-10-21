# VLC 9 para iOS 9 (iPad mini 1 / armv7)

Reproductor multimedia completo para iPad de 32 bits con iOS 9, basado en el
motor de **VLC (MobileVLCKit 3.7.4)**. Pensado para el iPad mini 1 (`iPad2,6`),
pero funciona en cualquier dispositivo armv7 con iOS 9.0 o superior.

## Qué necesitas

- Un dispositivo con **jailbreak** y **AppSync Unified**.
- Descargar el `.ipa` de este Release y abrirlo con **Filza** (o instalarlo por
  AFC/SSH con `ipainstaller`).
- No se necesita cuenta de desarrollador de Apple ni un Mac.

## Qué trae esta versión

- **Biblioteca por carpetas**: añade cualquier ruta del iPad (por ejemplo
  `/var/mobile/Media`) y analiza archivos y subcarpetas sin copiarlos.
- **Reproductor VLC** con gestos (volumen, brillo, búsqueda), pistas de audio y
  subtítulos, cambio de velocidad, relación de aspecto, capturas y repetición.
- **Reanudar donde lo dejaste** y marcadores de progreso en la biblioteca.
- **Listas de reproducción** locales y reproducción de carpetas completas.
- **Red**: URLs directas, historial, favoritos y explorador **UPnP/DLNA**.
- **Ajustes**: reanudación, audio en segundo plano, aceleración por hardware,
  desentrelazado, codificación de subtítulos y caché de red.
- Interfaz oscura inspirada en VLC, en español y adaptada a iPad.

## Cómo se instala

1. Copia el `.ipa` al iPad (`/var/mobile/Media`) por USB/AFC o desde Filza.
2. Ábrelo con Filza y toca **Instalar**.
3. Si iOS pide confianza, acepta el perfil.

La app se instala como **VLC 9** (`com.lofturb.vlc9`) y convive con el VLC
original sin reemplazarlo.

## Verificación

El `.ipa` se comprueba en cada build: contiene el ejecutable armv7 `VLC9`, el
framework `MobileVLCKit` firmado ad-hoc con `ldid`, el install name
`@rpath/MobileVLCKit.framework/MobileVLCKit` y los entitlements necesarios.

## Aviso legal

VLC es una marca de VideoLAN. Esta aplicación es un reproductor independiente
que usa el motor MobileVLCKit bajo la licencia GNU LGPL 2.1. No está afiliada a
VideoLAN ni a Apple.
