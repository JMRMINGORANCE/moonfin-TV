# Genera taquitoflix_wordmark.svg: el texto se convierte en trazos (no depende
# de fuentes instaladas). Uso: python3 make_wordmark.py Roboto-Bold.ttf
import re, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

font = TTFont(sys.argv[1])
gs = font.getGlyphSet(); cmap = font.getBestCmap(); upm = font['head'].unitsPerEm
text = "TaquitoFlix"; size = 200; scale = size / upm
rots = [-4, 3, -3, 4, -2, 3, -4, -3, 4, -3, 3]
x = 0; taquito = []; flix = []

def short(d):
    return re.sub(r"-?\d+\.\d+", lambda m: f"{float(m.group()):.1f}".rstrip("0").rstrip("."), d)

for i, ch in enumerate(text):
    glyph = gs[cmap[ord(ch)]]
    pen = SVGPathPen(gs)
    glyph.draw(TransformPen(pen, (scale, 0, 0, -scale, x, 0)))
    w = glyph.width * scale
    p = f'<path d="{short(pen.getCommands())}" transform="rotate({rots[i]} {x + w / 2:.0f} -70)"/>'
    (flix if i >= 7 else taquito).append(p)
    x += w + 8

pad, head = 34, 236
W = pad + head + 24 + x + pad + 10
inner = re.search(r"<svg[^>]*>(.*)</svg>", open("taquito_head.svg").read(), re.S).group(1)
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 {W:.0f} 290">
<defs>
<g id="t">{"".join(taquito)}</g>
<g id="f">{"".join(flix)}</g>
</defs>
<g transform="translate({pad} 22) scale({head / 512:.4f})">{inner}</g>
<g transform="translate({pad + head + 24} 222)" stroke-linejoin="round">
<g transform="translate(7 9)" fill="#000" stroke="#000" stroke-width="34"><use xlink:href="#t"/><use xlink:href="#f"/></g>
<g fill="#FFF" stroke="#FFF" stroke-width="26"><use xlink:href="#t"/><use xlink:href="#f"/></g>
<g stroke="#0B0707" stroke-width="8"><use xlink:href="#t" fill="#FFF"/><use xlink:href="#f" fill="#E50914"/></g>
</g>
</svg>
'''
open("taquitoflix_wordmark.svg", "w").write(svg)
