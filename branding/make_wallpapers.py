#!/usr/bin/env python3
"""TaquitoFlix: fondos del protector de pantalla, dibujados con Taquito.

Genera tres escenas en SVG (1920x1080) a partir de taquito_head.svg:
  1. Noche de cine: telón rojo, foco de luz y cubo de palomitas.
  2. Buenas noches: Taquito dormido sobre una nube bajo la luna.
  3. Pop: rayos rojos, trama de puntos y tira de película.

Al compilar los dibuja rebrand.py directamente. Para verlos a mano:
  python3 make_wallpapers.py      (deja los SVG en wallpapers/)
"""
import math
import random
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "wallpapers"
W, H = 1920, 1080

HEAD = (HERE / "taquito_head.svg").read_text(encoding="utf-8")
HEAD_INNER = re.search(r"<svg[^>]*>(.*)</svg>", HEAD, re.S).group(1)


def head(x, y, size, inner=HEAD_INNER, rotate=0):
    """Coloca la cabeza (dibujada en 512x512) centrada en (x, y)."""
    k = size / 512
    return (
        f'<g transform="translate({x - size / 2:.1f} {y - size / 2:.1f}) '
        f'rotate({rotate} {size / 2:.1f} {size / 2:.1f}) scale({k:.4f})">'
        f"{inner}</g>"
    )


def sleeping_head():
    """Variante con los ojos cerrados y la boca tranquila."""
    inner = HEAD_INNER
    eyes = re.search(r"<!-- ojos -->.*?(?=<!-- nariz -->)", inner, re.S).group(0)
    closed = """<!-- ojos cerrados -->
  <g fill="none" stroke="#0B0707" stroke-width="9" stroke-linecap="round">
    <path d="M170 300 Q202 330 234 300"/>
    <path d="M278 300 Q310 330 342 300"/>
  </g>
  <g fill="none" stroke="#0B0707" stroke-width="4" stroke-linecap="round">
    <path d="M176 306 L168 316"/><path d="M228 306 L236 316"/>
    <path d="M284 306 L276 316"/><path d="M336 306 L344 316"/>
  </g>
  """
    inner = inner.replace(eyes, closed)
    mouth = re.search(r"<!-- boca y lengua -->.*", inner, re.S).group(0)
    calm = """<!-- boca dormida -->
  <path d="M232 398 Q256 412 280 398" fill="none" stroke="#0B0707" stroke-width="7" stroke-linecap="round"/>
"""
    return inner.replace(mouth, calm)


def stars(n, seed, y_max, color="#FFFFFF"):
    rnd = random.Random(seed)
    out = []
    for _ in range(n):
        x, y = rnd.uniform(0, W), rnd.uniform(0, y_max)
        r = rnd.choice([1.2, 1.6, 2.2, 3])
        o = rnd.uniform(0.35, 1)
        out.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="{color}" opacity="{o:.2f}"/>')
    return "".join(out)


def sparkle(x, y, s, color="#FFE08A"):
    p = (f"M{x} {y - s} L{x + s * 0.22} {y - s * 0.22} L{x + s} {y} "
         f"L{x + s * 0.22} {y + s * 0.22} L{x} {y + s} L{x - s * 0.22} {y + s * 0.22} "
         f"L{x - s} {y} L{x - s * 0.22} {y - s * 0.22} Z")
    return f'<path d="{p}" fill="{color}"/>'


def crescent(x1, y1, r1, x2, y2, r2):
    """Luna creciente: el círculo 1 menos el círculo 2, como un único trazado."""
    d = math.hypot(x2 - x1, y2 - y1)
    a = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    h = math.sqrt(max(r1 * r1 - a * a, 0))
    mx, my = x1 + a * (x2 - x1) / d, y1 + a * (y2 - y1) / d
    px, py = -(y2 - y1) / d * h, (x2 - x1) / d * h
    ax, ay = mx + px, my + py
    bx, by = mx - px, my - py
    return (f"M{ax:.1f} {ay:.1f} A{r1} {r1} 0 1 1 {bx:.1f} {by:.1f} "
            f"A{r2} {r2} 0 0 0 {ax:.1f} {ay:.1f} Z")


def svg(body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}">'
            f"<defs>{defs}</defs>{body}</svg>\n")


# ---------------------------------------------------------------------------
# 1. Noche de cine
# ---------------------------------------------------------------------------

def cinema_night():
    defs = """
  <radialGradient id="bg1" cx="0.5" cy="0.55" r="0.75">
    <stop offset="0" stop-color="#4A0508"/><stop offset="0.6" stop-color="#1A0103"/>
    <stop offset="1" stop-color="#050000"/>
  </radialGradient>
  <linearGradient id="curtain" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#7A0309"/><stop offset="0.5" stop-color="#C40812"/>
    <stop offset="1" stop-color="#6A0207"/>
  </linearGradient>
  <linearGradient id="beam" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFF6D8" stop-opacity="0.55"/>
    <stop offset="1" stop-color="#FFF6D8" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="valance" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#9E050D"/><stop offset="1" stop-color="#5E0206"/>
  </linearGradient>"""
    body = ['<rect width="1920" height="1080" fill="url(#bg1)"/>']
    # Haz de luz desde arriba.
    body.append('<path d="M860 0 L1060 0 L1420 1080 L500 1080 Z" fill="url(#beam)"/>')
    body.append('<ellipse cx="960" cy="1010" rx="520" ry="60" fill="#FFF6D8" opacity="0.12"/>')
    # Telones con pliegues.
    for side in (0, 1):
        for i in range(6):
            w = 70
            x = i * w if side == 0 else W - (i + 1) * w
            sway = 26 if side == 0 else -26
            d = (f"M{x} 0 L{x + w} 0 Q{x + w + sway * 0.4} 540 {x + w + sway} 1080 "
                 f"L{x + sway} 1080 Q{x + sway * 0.4} 540 {x} 0 Z")
            body.append(f'<path d="{d}" fill="url(#curtain)" opacity="{0.92 - i * 0.05:.2f}"/>')
    # Cenefa superior ondulada.
    wave = "M0 0 L1920 0 L1920 90 " + " ".join(
        f"Q{1920 - i * 120 - 60} 150 {1920 - (i + 1) * 120} 90" for i in range(16)) + " Z"
    body.append(f'<path d="{wave}" fill="url(#valance)"/>')
    body.append('<rect y="0" width="1920" height="14" fill="#E3B341"/>')
    # Taquito.
    body.append(head(960, 600, 620))
    # Cubo de palomitas.
    bx, by = 1300, 760
    stripes = []
    for i in range(6):
        x0 = bx - 120 + i * 40
        stripes.append(f'<path d="M{x0} {by} L{x0 + 40} {by} L{x0 + 36 - (i - 2.5) * 2} {by + 250} '
                       f'L{x0 + 4 - (i - 2.5) * 2} {by + 250} Z" '
                       f'fill="{"#E50914" if i % 2 == 0 else "#FFFFFF"}"/>')
    pop = []
    rnd = random.Random(7)
    for _ in range(26):
        px = bx + rnd.uniform(-115, 115)
        py = by + rnd.uniform(-70, 10)
        r = rnd.uniform(18, 28)
        pop.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="{r:.0f}" fill="#FFF3C4" stroke="#E8B64A" stroke-width="3"/>')
    body.append('<g transform="rotate(8 1300 880)">'
                f'<path d="M{bx - 132} {by - 8} L{bx + 132} {by - 8} L{bx + 112} {by + 258} L{bx - 112} {by + 258} Z" '
                'fill="#FFFFFF" stroke="#FFFFFF" stroke-width="22" stroke-linejoin="round"/>'
                + "".join(pop) + "".join(stripes) +
                f'<rect x="{bx - 130}" y="{by - 6}" width="260" height="26" rx="6" fill="#B8060F"/>'
                '</g>')
    for (x, y, s) in [(560, 300, 22), (1420, 320, 18), (650, 820, 14), (1500, 560, 12), (420, 600, 10)]:
        body.append(sparkle(x, y, s))
    return svg("".join(body), defs)


# ---------------------------------------------------------------------------
# 2. Buenas noches
# ---------------------------------------------------------------------------

def good_night():
    defs = """
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#070B22"/><stop offset="0.65" stop-color="#16224F"/>
    <stop offset="1" stop-color="#2A2F6B"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#FFF1B8" stop-opacity="0.45"/>
    <stop offset="1" stop-color="#FFF1B8" stop-opacity="0"/>
  </radialGradient>
"""
    body = ['<rect width="1920" height="1080" fill="url(#sky)"/>', stars(170, 3, 820)]
    body.append('<circle cx="1560" cy="250" r="330" fill="url(#glow)"/>')
    body.append(f'<path d="{crescent(1560, 250, 130, 1620, 210, 120)}" fill="#FFF3C8"/>')
    for (x, y, s) in [(380, 220, 16), (1180, 140, 12), (820, 380, 10), (1720, 520, 14)]:
        body.append(sparkle(x, y, s, "#FFF3C8"))
    # Nubes lejanas.
    for (x, y, s, o) in [(300, 900, 1.3, 0.10), (1500, 930, 1.6, 0.10), (980, 1000, 2.0, 0.08)]:
        body.append(f'<g opacity="{o}" transform="translate({x} {y}) scale({s})">'
                    '<ellipse cx="0" cy="0" rx="220" ry="60" fill="#FFF"/>'
                    '<ellipse cx="-90" cy="-35" rx="110" ry="70" fill="#FFF"/>'
                    '<ellipse cx="70" cy="-45" rx="130" ry="85" fill="#FFF"/></g>')
    # Nube principal con Taquito durmiendo encima.
    body.append('<g transform="translate(860 860)">'
                '<ellipse cx="0" cy="40" rx="430" ry="95" fill="#DCE3FF"/>'
                '<ellipse cx="-230" cy="-10" rx="190" ry="120" fill="#EEF2FF"/>'
                '<ellipse cx="40" cy="-40" rx="240" ry="150" fill="#F6F8FF"/>'
                '<ellipse cx="280" cy="0" rx="180" ry="110" fill="#EEF2FF"/>'
                '<ellipse cx="0" cy="60" rx="400" ry="70" fill="#FFFFFF"/></g>')
    body.append(head(870, 640, 520, inner=sleeping_head(), rotate=-12))
    # Zzz.
    for (x, y, s, o) in [(1110, 440, 46, 0.95), (1190, 360, 34, 0.75), (1250, 300, 24, 0.55)]:
        body.append(f'<path d="M{x} {y} L{x + s} {y} L{x} {y + s} L{x + s} {y + s}" fill="none" '
                    f'stroke="#FFF3C8" stroke-width="{s / 6:.1f}" stroke-linecap="round" '
                    f'stroke-linejoin="round" opacity="{o}"/>')
    return svg("".join(body), defs)


# ---------------------------------------------------------------------------
# 3. Pop
# ---------------------------------------------------------------------------

def pop_art():
    defs = """
  <pattern id="dots" width="28" height="28" patternUnits="userSpaceOnUse">
    <circle cx="14" cy="14" r="5" fill="#000" opacity="0.18"/>
  </pattern>
  <radialGradient id="fade" cx="0.5" cy="0.5" r="0.6">
    <stop offset="0.45" stop-color="#000" stop-opacity="0"/>
    <stop offset="1" stop-color="#000" stop-opacity="0.55"/>
  </radialGradient>"""
    cx, cy = 960, 500
    rays = []
    n = 28
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 0.5) / n
        p0 = (cx + 2400 * math.cos(a0), cy + 2400 * math.sin(a0))
        p1 = (cx + 2400 * math.cos(a1), cy + 2400 * math.sin(a1))
        rays.append(f'<path d="M{cx} {cy} L{p0[0]:.0f} {p0[1]:.0f} L{p1[0]:.0f} {p1[1]:.0f} Z" fill="#C70711"/>')
    body = ['<rect width="1920" height="1080" fill="#E50914"/>', "".join(rays),
            '<rect width="1920" height="1080" fill="url(#dots)"/>',
            '<rect width="1920" height="1080" fill="url(#fade)"/>']
    # Halo blanco detrás de Taquito.
    body.append(f'<circle cx="{cx}" cy="{cy}" r="360" fill="#FFFFFF" opacity="0.14"/>')
    body.append(f'<circle cx="{cx}" cy="{cy}" r="300" fill="#FFFFFF" opacity="0.10"/>')
    body.append(head(cx, cy, 640))
    # Tira de película abajo.
    film = ['<g transform="rotate(-3 960 960)">',
            '<rect x="-60" y="890" width="2040" height="150" fill="#0B0707"/>']
    for i in range(36):
        x = -40 + i * 58
        film.append(f'<rect x="{x}" y="902" width="34" height="22" rx="4" fill="#F4F4F4"/>')
        film.append(f'<rect x="{x}" y="1006" width="34" height="22" rx="4" fill="#F4F4F4"/>')
    for i in range(9):
        x = 20 + i * 220
        film.append(f'<rect x="{x}" y="938" width="190" height="56" rx="4" fill="#2A2A2A"/>')
    film.append("</g>")
    body.append("".join(film))
    for (x, y, s) in [(520, 200, 26), (1430, 230, 20), (1500, 700, 16), (400, 700, 14)]:
        body.append(sparkle(x, y, s, "#FFFFFF"))
    return svg("".join(body), defs)


# Los usa rebrand.py al compilar (nombre del archivo, función que lo dibuja).
WALLPAPERS = [
    ("taquito_wall_1", cinema_night),
    ("taquito_wall_2", good_night),
    ("taquito_wall_3", pop_art),
]

if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for name, fn in WALLPAPERS:
        (OUT / f"{name}.svg").write_text(fn(), encoding="utf-8")
        print("generado", name)
