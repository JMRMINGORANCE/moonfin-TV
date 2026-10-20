#!/usr/bin/env python3
"""TaquitoFlix para Samsung: cambio de marca de la app de tele de Moonfin.

Se ejecuta dentro del código de Moonfin Smart-TV (ya con el parche y la
carpeta overlay aplicados) y:
  1. Pone el nombre, el identificador y la versión de TaquitoFlix en el
     config.xml de Tizen (mismo id que la versión anterior, para que se
     instale encima).
  2. Cambia "Moonfin" por "TaquitoFlix" solo en los textos que ve el usuario
     que hablan de la app (el plugin del servidor se sigue llamando Moonfin).
  3. Deja el español como idioma y tu servidor ya escrito al añadir uno.
  4. Genera iconos, logotipos y pantalla de carga con Taquito.

Uso:  python3 rebrand_tv.py <carpeta-smart-tv> <version-x.y.z>
Necesita:  pip install cairosvg pillow
"""
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BRANDING = HERE.parent.parent / "branding"
sys.path.insert(0, str(BRANDING))

# Funciones de dibujo compartidas con la versión de Android.
import rebrand as base  # noqa: E402

BRAND = "TaquitoFlix"
APP_ID = "TaquitoFlx.TaquitoFlix"
PACKAGE = "TaquitoFlx"
WIDGET_ID = "http://josemingorance.es/taquitoflix"
DEFAULT_SERVER = "https://tv.josemingorance.es"

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
VERSION = sys.argv[2] if len(sys.argv) > 2 else "2.7.0"
APP = ROOT / "packages/app"
TIZEN = ROOT / "packages/build-tizen/tizen"


def log(msg):
    print(f"[rebrand-tv] {msg}", flush=True)


def edit(path: Path, pairs, required=True):
    text = path.read_text(encoding="utf-8")
    for pattern, repl in pairs:
        new, n = re.subn(pattern, repl, text, flags=re.S)
        if n == 0 and required:
            sys.exit(f"[rebrand-tv] no encontré {pattern!r} en {path}")
        text = new
    path.write_text(text, encoding="utf-8")


# ---------------------------------------------------------------------------
# 1. config.xml de Tizen
# ---------------------------------------------------------------------------

def tizen_config():
    cfg = TIZEN / "config.xml"
    edit(cfg, [
        (r'(<widget[^>]*\bid=")[^"]*(")', rf'\g<1>{WIDGET_ID}\g<2>'),
        (r'(<widget[^>]*\bversion=")[^"]*(")', rf'\g<1>{VERSION}\g<2>'),
        (r'(<tizen:application[^>]*\bid=")[^"]*(")', rf'\g<1>{APP_ID}\g<2>'),
        (r'(<tizen:application[^>]*\bpackage=")[^"]*(")', rf'\g<1>{PACKAGE}\g<2>'),
        (r'<name>[^<]*</name>', f'<name>{BRAND}</name>'),
        (r'<description>[^<]*</description>',
         '<description>TaquitoFlix: tu Jellyfin con aspecto de plataforma de streaming.</description>'),
        # El servicio de vista previa de Smart Hub lleva el id del paquete.
        (r'(<tizen:service[^>]*\bid=")[^".]*(\.[^"]*")', rf'\g<1>{PACKAGE}\g<2>'),
    ])
    log(f"config.xml: {APP_ID} versión {VERSION}")


# ---------------------------------------------------------------------------
# 2. Textos
# ---------------------------------------------------------------------------

# Claves (en inglés, como las usa la app) cuyo texto habla de la propia app.
APP_NAME_KEYS = [
    "Exit Moonfin?",
    "Moonfin version {version}",
    "Support Moonfin",
    "Moonfin User",
]


def spanish():
    """Completa el español con lo que a Moonfin le falta por traducir."""
    extra = json.loads((HERE / "es_extra.json").read_text(encoding="utf-8"))
    path = APP / "resources/es/strings.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    added = 0
    for key, value in extra.items():
        if key not in data:
            data[key] = value
            added += 1
    path.write_text(json.dumps(data, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    log(f"español: {added} textos traducidos de más")


def rebrand_strings():
    changed = 0
    base_file = APP / "resources/strings.json"
    files = [base_file] + sorted((APP / "resources").glob("*/strings.json"))
    for path in files:
        data = json.loads(path.read_text(encoding="utf-8"))
        before = changed
        for key in APP_NAME_KEYS:
            value = data.get(key, key if path == base_file else None)
            if value is None:
                continue
            new = value.replace("Moonfin", BRAND)
            if data.get(key) != new:
                data[key] = new
                changed += 1
        if changed != before:
            path.write_text(json.dumps(data, ensure_ascii=False, indent=4) + "\n",
                            encoding="utf-8")
    log(f"textos con el nombre de la app: {changed}")


# ---------------------------------------------------------------------------
# 3. Idioma y servidor por defecto
# ---------------------------------------------------------------------------

def defaults():
    edit(APP / "src/context/defaultSettings.js", [
        (r"uiLanguage:\s*'[^']*'", "uiLanguage: 'es'"),
    ])
    edit(APP / "src/views/Login/Login.js", [
        (r"const \[addressValue, setAddressValue\] = useState\(''\);",
         f"const [addressValue, setAddressValue] = useState('{DEFAULT_SERVER}');"),
    ])
    log(f"idioma español y servidor {DEFAULT_SERVER}")


# ---------------------------------------------------------------------------
# 4. Imágenes
# ---------------------------------------------------------------------------

def save(img, path: Path, rgb=False):
    if rgb:
        from PIL import Image
        flat = Image.new("RGB", img.size, (0, 0, 0))
        flat.paste(img, mask=img.split()[3])
        img = flat
    img.save(path, optimize=True)
    log(f"generado {path.relative_to(ROOT)} {img.size[0]}x{img.size[1]}")


def images():
    head, word = base.HEAD_SVG, base.WORDMARK_SVG
    red = base.RED
    # Icono cuadrado de la app y miniaturas.
    save(base.compose(512, 512, red, head, 0.86, rounded=0.22), TIZEN / "icon.png")
    save(base.compose(115, 115, red, head, 0.86, rounded=0.22), TIZEN / "icon-small.png")
    save(base.compose(80, 80, red, head, 0.86, rounded=0.22), APP / "resources/icon-80.png")
    save(base.compose(130, 130, red, head, 0.86, rounded=0.22), APP / "resources/icon-130.png")
    # Iconos apaisados y pantalla de carga: logotipo sobre negro.
    for name in ["icon-large.png", "icon-oblong.png", "splash.png"]:
        save(base.compose(1920, 1080, "#000000", word, 0.62), TIZEN / name, rgb=True)
    save(base.compose(1920, 1080, "#000000", word, 0.62), APP / "resources/splash.png", rgb=True)
    # Logotipos con texto (inicio de sesión, ajustes, protector de pantalla).
    w, h = base.viewbox(word)
    save(base.render(word, 1179, round(1179 * h / w)), APP / "resources/logo-and-text.png")
    save(base.compose(1920, 640, None, word, 0.9), APP / "resources/banner-dark.png")
    # Taquito para las pantallas propias (cargando, vacíos, perfiles) y los
    # fondos del protector de pantalla.
    cine = APP / "resources/cine"
    cine.mkdir(parents=True, exist_ok=True)
    (cine / "taquito.svg").write_text(head, encoding="utf-8")
    (cine / "wordmark.svg").write_text(word, encoding="utf-8")
    log("generado resources/cine/taquito.svg y wordmark.svg")
    import make_wallpapers as wp
    from PIL import Image
    import io
    for i, (name, fn) in enumerate(wp.WALLPAPERS, 1):
        png = base.cairosvg.svg2png(bytestring=fn().encode("utf-8"), output_width=1920, output_height=1080)
        img = Image.open(io.BytesIO(png)).convert("RGB")
        out = cine / f"wallpaper-{i}.jpg"
        img.save(out, quality=86, optimize=True)
        log(f"generado {out.relative_to(ROOT)} ({name})")


if __name__ == "__main__":
    if not (ROOT / "packages/build-tizen").exists():
        sys.exit("Indica la carpeta del código de Moonfin Smart-TV.")
    tizen_config()
    spanish()
    rebrand_strings()
    defaults()
    images()
    log("listo")
