# -*- coding: utf-8 -*-
"""
Genera los iconos e imagenes de arranque de VLC 9, sin dependencias externas.

Escribe PNGs a mano con zlib + struct (biblioteca estandar), asi que funciona
en Windows con Python 3.8 sin Pillow.

Diseno: fondo casi negro, cono de trafico naranja de VLC con bandas crema.
Produce:
  app/Resources/              -> iconos del sistema e imagenes de arranque
  app/recursos-generados.txt  -> resumen de lo creado

Uso (desde la raiz del proyecto):
    python tools/generar_recursos.py
"""

import io
import os
import struct
import sys
import zlib


def raiz_proyecto():
    """Acepta --raiz; si no, usa el directorio actual (si tiene app/) o el
    abuelo de este script (cuando vive en tools/)."""
    if "--raiz" in sys.argv:
        i = sys.argv.index("--raiz")
        if i + 1 < len(sys.argv):
            return os.path.abspath(sys.argv[i + 1])
    actual = os.getcwd()
    if os.path.isdir(os.path.join(actual, "app")):
        return actual
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


RAIZ = raiz_proyecto()
DESTINO = os.path.join(RAIZ, "app", "Resources")

# Paleta VLC 9.
FONDO = (0x0E, 0x0E, 0x10, 255)       # negro de la interfaz
ACENTO = (0xFF, 0x88, 0x00, 255)      # naranja VLC
CREMA = (0xFF, 0xF1, 0xDC, 255)       # bandas del cono
SOMBRA = (0xC9, 0x63, 0x00, 255)      # base del cono


def escribir_png(ruta, ancho, alto, pixeles):
    """pixeles: bytearray RGBA de ancho*alto*4."""
    filas = []
    for y in range(alto):
        inicio = y * ancho * 4
        filas.append(b"\x00" + bytes(pixeles[inicio:inicio + ancho * 4]))
    crudo = b"".join(filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    cabecera = struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0)
    contenido = (b"\x89PNG\r\n\x1a\n"
                 + bloque(b"IHDR", cabecera)
                 + bloque(b"IDAT", zlib.compress(crudo, 9))
                 + bloque(b"IEND", b""))
    with io.open(ruta, "wb") as f:
        f.write(contenido)


def dentro_del_redondeo(x, y, ancho, alto, radio):
    """Esquinas redondeadas estilo iOS."""
    cx = min(max(x, radio), ancho - radio)
    cy = min(max(y, radio), alto - radio)
    dx, dy = x - cx, y - cy
    return dx * dx + dy * dy <= radio * radio


def dentro_del_cono(x, y, ancho, alto):
    """Cono de trafico centrado. x/y en pixeles del cuadro."""
    nx = x / float(ancho)
    ny = y / float(alto)

    # Cuerpo: triangulo con la punta ligeramente truncada.
    if 0.155 <= ny < 0.715:
        t = (ny - 0.155) / (0.715 - 0.155)
        medio = 0.018 + 0.170 * t
        return abs(nx - 0.5) <= medio

    # Base: rectangulo con esquinas redondeadas.
    if 0.715 <= ny <= 0.825:
        if not (0.185 <= nx <= 0.815):
            return False
        radio = 0.045 * ancho
        return dentro_del_redondeo(x, y, ancho, alto, radio)

    return False


def en_banda_del_cono(x, y, ancho, alto):
    """Bandas reflectantes crema del cono."""
    ny = y / float(alto)
    if not (0.155 < ny < 0.715):
        return False
    return (0.345 <= ny <= 0.425) or (0.520 <= ny <= 0.600)


def color_del_cono(x, y, ancho, alto):
    if not dentro_del_cono(x, y, ancho, alto):
        return None
    ny = y / float(alto)
    if ny >= 0.715:
        return SOMBRA
    if en_banda_del_cono(x, y, ancho, alto):
        return CREMA
    return ACENTO


def icono(ancho, alto, con_fondo=True):
    """Icono cuadrado con supermuestreo 3x para bordes suaves."""
    sup = 3
    radio = 0.2237 * ancho
    pixeles = bytearray(ancho * alto * 4)

    for y in range(alto):
        for x in range(ancho):
            acumulado = [0.0, 0.0, 0.0, 0.0]
            for sy in range(sup):
                for sx in range(sup):
                    px = x + (sx + 0.5) / sup
                    py = y + (sy + 0.5) / sup
                    if con_fondo and not dentro_del_redondeo(px, py, ancho, alto, radio):
                        color = (0, 0, 0, 0)
                    else:
                        color = color_del_cono(px, py, ancho, alto)
                        if color is None:
                            color = FONDO
                    for i in range(4):
                        acumulado[i] += color[i]
            n = sup * sup
            base = (y * ancho + x) * 4
            for i in range(4):
                pixeles[base + i] = int(round(acumulado[i] / n))
    return pixeles


def arranque(ancho, alto):
    """Imagen de arranque: fondo oscuro con el cono centrado."""
    pixeles = bytearray(ancho * alto * 4)
    lado = int(min(ancho, alto) * 0.34)
    ox = (ancho - lado) // 2
    oy = (alto - lado) // 2

    for y in range(alto):
        for x in range(ancho):
            base = (y * ancho + x) * 4
            color = None
            if ox <= x < ox + lado and oy <= y < oy + lado:
                color = color_del_cono(x - ox, y - oy, lado, lado)
            if color is None:
                color = FONDO
            pixeles[base:base + 4] = bytes(color)
    return pixeles


ICONOS = [
    ("Icon-Small.png", 29),
    ("Icon-Small@2x.png", 58),
    ("Icon-Small-40.png", 40),
    ("Icon-Small-40@2x.png", 80),
    ("Icon-Small-40@3x.png", 120),
    ("Icon-60.png", 60),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-72.png", 72),
    ("Icon-72@2x.png", 144),
    ("Icon-76.png", 76),
    ("Icon-76@2x.png", 152),
    ("iTunesArtwork", 512),
]

ARRANQUES = [
    ("LaunchImage.png", 320, 480),
    ("LaunchImage@2x.png", 640, 960),
    ("LaunchImage-568h@2x.png", 640, 1136),
    ("LaunchImage-700.png", 320, 480),
    ("LaunchImage-700@2x.png", 640, 960),
    ("LaunchImage-700-568h@2x.png", 640, 1136),
    ("LaunchImage-700-Portrait.png", 768, 1024),
    ("LaunchImage-700-Portrait@2x.png", 1536, 2048),
    ("LaunchImage-700-Landscape.png", 1024, 768),
    ("LaunchImage-700-Landscape@2x.png", 2048, 1536),
]


def main():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)
    hechos = []

    print("  Raiz:    %s" % RAIZ)
    print("  Destino: %s" % DESTINO)
    print("")

    for nombre, lado in ICONOS:
        escribir_png(os.path.join(DESTINO, nombre), lado, lado,
                     icono(lado, lado, con_fondo=(nombre != "iTunesArtwork")))
        hechos.append("%s  %dx%d" % (nombre, lado, lado))

    for nombre, ancho, alto in ARRANQUES:
        escribir_png(os.path.join(DESTINO, nombre), ancho, alto, arranque(ancho, alto))
        hechos.append("%s  %dx%d" % (nombre, ancho, alto))

    resumen = os.path.join(RAIZ, "app", "recursos-generados.txt")
    with io.open(resumen, "w", encoding="utf-8") as f:
        f.write("Recursos generados por tools/generar_recursos.py\n\n")
        f.write("\n".join(hechos) + "\n")

    print("Generados %d archivos en app/Resources" % len(hechos))
    for h in hechos:
        print("   ", h)


if __name__ == "__main__":
    main()
