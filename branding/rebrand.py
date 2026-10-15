#!/usr/bin/env python3
"""TaquitoFlix: cambio de marca durante la compilación.

Se ejecuta dentro del código de Moonfin ya parcheado (carpeta src) y:
  1. Cambia "Moonfin" por "TaquitoFlix" en los textos traducidos (solo en
     valores de texto, nunca en nombres de código).
  2. Genera todos los iconos, logos, banner de TV y pantallas de carga a partir
     de los SVG de esta carpeta (el dibujo del perro está en taquito_head.svg).

Uso:  python3 ../branding/rebrand.py   (desde la carpeta src)
Necesita:  pip install cairosvg pillow
"""
import io
import json
import re
import shutil
import sys
from pathlib import Path

import cairosvg
from PIL import Image

BRAND = "TaquitoFlix"
RED = "#E50914"
HERE = Path(__file__).resolve().parent
SRC = Path.cwd()
HEAD_SVG = (HERE / "taquito_head.svg").read_text(encoding="utf-8")
WORDMARK_SVG = (HERE / "taquitoflix_wordmark.svg").read_text(encoding="utf-8")


def log(msg):
    print(f"[rebrand] {msg}", flush=True)


# ---------------------------------------------------------------------------
# 1. Textos
# ---------------------------------------------------------------------------

WORD = re.compile(r"(?<![A-Za-z0-9_$])Moonfin(?![A-Za-z0-9_])")


def rebrand_text(value: str) -> str:
    # El plugin del servidor se sigue llamando Moonfin: las rutas /Moonfin/...
    # no aparecen en las traducciones, así que basta con la palabra suelta.
    return WORD.sub(BRAND, value)


def rebrand_arb(path: Path):
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = 0
    for key, value in list(data.items()):
        if key.startswith("@") or not isinstance(value, str):
            continue
        new = rebrand_text(value)
        if new != value:
            data[key] = new
            changed += 1
    if changed:
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    return changed


STRING_LITERAL = re.compile(r"'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\"")


def rebrand_dart_strings(path: Path):
    text = path.read_text(encoding="utf-8")
    count = 0

    def fix(match):
        nonlocal count
        new = rebrand_text(match.group(0))
        if new != match.group(0):
            count += 1
        return new

    new_text = STRING_LITERAL.sub(fix, text)
    if count:
        path.write_text(new_text, encoding="utf-8")
    return count


# Textos concretos que cambian solo en español (por clave, así no dependen de
# en qué línea estén y sobreviven a las actualizaciones de Moonfin).
ES_OVERRIDES = {
    "libraries": "Mi biblioteca",
}


def spanish_overrides():
    count = 0
    for arb in sorted((SRC / "lib/l10n").glob("app_es*.arb")):
        data = json.loads(arb.read_text(encoding="utf-8"))
        for key, value in ES_OVERRIDES.items():
            if key in data and data[key] != value:
                data[key] = value
                count += 1
        arb.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    dart = SRC / "lib/l10n/app_localizations_es.dart"
    if dart.exists():
        text = dart.read_text(encoding="utf-8")
        for key, value in ES_OVERRIDES.items():
            text, n = re.subn(
                rf"(String get {key} =>\s*)'(?:[^'\\]|\\.)*';",
                lambda m, v=value: f"{m.group(1)}'{v}';",
                text,
            )
            count += n
        dart.write_text(text, encoding="utf-8")
    log(f"textos en español ajustados: {count}")


def rebrand_translations():
    total = 0
    for arb in sorted((SRC / "lib/l10n").glob("*.arb")):
        total += rebrand_arb(arb)
    for dart in sorted((SRC / "lib/l10n").glob("app_localizations*.dart")):
        total += rebrand_dart_strings(dart)
    log(f"textos traducidos actualizados: {total}")


# ---------------------------------------------------------------------------
# 2. Imágenes
# ---------------------------------------------------------------------------


def svg_inner(svg: str) -> str:
    return re.search(r"<svg[^>]*>(.*)</svg>", svg, re.S).group(1)


def viewbox(svg: str):
    vb = re.search(r'viewBox="([^"]+)"', svg).group(1).split()
    return float(vb[2]), float(vb[3])


def render(svg: str, width: int, height: int) -> Image.Image:
    png = cairosvg.svg2png(
        bytestring=svg.encode("utf-8"), output_width=width, output_height=height
    )
    return Image.open(io.BytesIO(png)).convert("RGBA")


def compose(width, height, background, art_svg, art_fraction, rounded=0.0,
            circle=False):
    """Coloca un dibujo centrado sobre un fondo (o transparente)."""
    w, h = viewbox(art_svg)
    k = min(width * art_fraction / w, height * art_fraction / h)
    aw, ah = w * k, h * k
    ax, ay = (width - aw) / 2, (height - ah) / 2
    bg = ""
    if background:
        if circle:
            bg = f'<circle cx="{width/2}" cy="{height/2}" r="{min(width,height)/2}" fill="{background}"/>'
        else:
            r = min(width, height) * rounded
            bg = f'<rect width="{width}" height="{height}" rx="{r}" fill="{background}"/>'
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'xmlns:xlink="http://www.w3.org/1999/xlink" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">{bg}'
        f'<g transform="translate({ax:.2f} {ay:.2f}) scale({aw / w:.5f} {ah / h:.5f})">'
        f"{svg_inner(art_svg)}</g></svg>"
    )
    return render(svg, width, height)


def save(img: Image.Image, rel: str, mode=None):
    path = SRC / rel
    if not path.parent.exists():
        log(f"(omitido, no existe la carpeta) {rel}")
        return
    if mode == "RGB":
        flat = Image.new("RGB", img.size, (0, 0, 0))
        flat.paste(img, mask=img.split()[3])
        img = flat
    img.save(path, optimize=True)
    log(f"generado {rel} {img.size[0]}x{img.size[1]}")


def size_of(rel, default):
    path = SRC / rel
    try:
        return Image.open(path).size
    except Exception:
        return default


def make_images():
    # Logo animado de carga y pantallas que usan el SVG directamente.
    for rel in ["assets/icons/moonfin_logo.svg"]:
        if (SRC / rel).exists():
            (SRC / rel).write_text(HEAD_SVG, encoding="utf-8")
            log(f"sustituido {rel}")

    # Logotipo con texto (pantallas de inicio de sesión, ajustes, salvapantallas).
    w, h = viewbox(WORDMARK_SVG)
    save(render(WORDMARK_SVG, 1179, round(1179 * h / w)),
         "assets/images/logo_and_text.png")

    # Icono de la app.
    save(compose(1024, 1024, RED, HEAD_SVG, 0.86, rounded=0.22),
         "assets/icons/app_icon.png")
    save(compose(512, 512, RED, HEAD_SVG, 0.86, rounded=0.22),
         "assets/icons/moonfin.png")

    # Pantalla de carga.
    save(compose(1920, 1080, "#000000", WORDMARK_SVG, 0.62),
         "assets/images/splash.png", mode="RGB")

    # Android: iconos clásicos y adaptativos.
    res = "android/app/src/main/res"
    for density, legacy, fg in [
        ("mdpi", 48, 108), ("hdpi", 72, 162), ("xhdpi", 96, 216),
        ("xxhdpi", 144, 324), ("xxxhdpi", 192, 432),
    ]:
        save(compose(legacy, legacy, RED, HEAD_SVG, 0.84, circle=True),
             f"{res}/mipmap-{density}/ic_launcher.png")
        # Zona segura del icono adaptativo: el 66 % central.
        save(compose(fg, fg, None, HEAD_SVG, 0.62),
             f"{res}/mipmap-{density}/ic_launcher_foreground.png")
    # Banner de Android TV (320x180).
    save(compose(640, 360, "#000000", WORDMARK_SVG, 0.95),
         f"{res}/drawable-nodpi/moonfin_tv_banner.png")

    # Fondos del protector de pantalla, dibujados con Taquito.
    sys.path.insert(0, str(HERE))
    import make_wallpapers
    for name, draw in make_wallpapers.WALLPAPERS:
        img = render(draw(), 1920, 1080)
        flat = Image.new("RGB", img.size, (0, 0, 0))
        flat.paste(img, mask=img.split()[3])
        flat.save(SRC / "assets/images" / f"{name}.jpg", quality=88, optimize=True)
        log(f"generado assets/images/{name}.jpg 1920x1080")

    # Web y Samsung Tizen (el paquete de Tizen usa Icon-512.png).
    for name, size, frac, rounded in [
        ("web/icons/Icon-192.png", 192, 0.86, 0.22),
        ("web/icons/Icon-512.png", 512, 0.86, 0.22),
        ("web/icons/Icon-maskable-192.png", 192, 0.66, 0.0),
        ("web/icons/Icon-maskable-512.png", 512, 0.66, 0.0),
        ("web/favicon.png", 64, 0.9, 0.22),
    ]:
        save(compose(size, size, RED, HEAD_SVG, frac, rounded=rounded), name)


def android_colors():
    # Fondo rojo del icono adaptativo.
    path = SRC / "android/app/src/main/res/values/ic_launcher_background.xml"
    if path.exists():
        text = re.sub(r'(<color name="ic_launcher_background">)[^<]*(</color>)',
                      rf"\g<1>{RED}\g<2>", path.read_text(encoding="utf-8"))
        path.write_text(text, encoding="utf-8")
        log("color del icono: rojo")
    # Pantalla de arranque negra (como las plataformas de streaming).
    for rel in ["android/app/src/main/res/values-v31/styles.xml",
                "android/app/src/main/res/values-night-v31/styles.xml"]:
        p = SRC / rel
        if p.exists():
            t = p.read_text(encoding="utf-8").replace(
                '"android:windowSplashScreenBackground">@color/ic_launcher_background',
                '"android:windowSplashScreenBackground">@android:color/black')
            p.write_text(t, encoding="utf-8")
    for rel in ["android/app/src/main/res/drawable/launch_background.xml",
                "android/app/src/main/res/drawable-v21/launch_background.xml"]:
        p = SRC / rel
        if p.exists():
            t = p.read_text(encoding="utf-8").replace(
                '@color/ic_launcher_background', '@android:color/black')
            p.write_text(t, encoding="utf-8")


if __name__ == "__main__":
    if not (SRC / "pubspec.yaml").exists():
        sys.exit("Ejecuta este script desde la carpeta del código (src).")
    rebrand_translations()
    spanish_overrides()
    make_images()
    android_colors()
    shutil.copy(HERE / "taquito_head.svg", SRC / "assets/icons/taquito_head.svg")
    log("listo")
