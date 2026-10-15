#!/usr/bin/env python3
"""TaquitoFlix: capas de Taquito para la animación de carga.

Separa taquito_head.svg en piezas que la app mueve por separado (todas en el
mismo lienzo de 512x512, así encajan al ponerlas una encima de otra):
  body       contorno blanco de la cabeza y la lengua (detrás de todo)
  ear_left   oreja izquierda con su contorno
  ear_right  oreja derecha con su contorno
  face       cabeza, ojos, nariz y boca
  blink      párpados cerrados (se encienden un instante para parpadear)
"""
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
HEAD = (HERE / "taquito_head.svg").read_text(encoding="utf-8")


def _between(start, end):
    return re.search(re.escape(start) + r"(.*?)" + re.escape(end), HEAD, re.S).group(1)


def layers():
    defs = re.search(r"<defs>.*?</defs>", HEAD, re.S).group(0)
    outline = _between("<!-- contorno blanco tipo pegatina -->", "<!-- orejas -->")
    outline_open = re.search(r"<g [^>]*>", outline).group(0)
    outline_paths = re.findall(r"<path [^>]*/>", outline)
    ears = _between("<!-- orejas -->", "<!-- cabeza -->")
    ear_open = re.search(r"<g [^>]*>", ears).group(0)
    ear_group = re.search(r"<g [^>]*>(.*?)</g>", ears, re.S).group(1)
    ear_paths = re.findall(r"<path [^>]*/>", ear_group)
    inner_paths = re.findall(r"<path [^>]*/>", ears[ears.index("</g>"):])
    face = HEAD[HEAD.index("<!-- cabeza -->"):HEAD.rindex("</svg>")]

    def svg(body):
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
                f"{defs}{body}</svg>\n")

    def ear(i):
        return svg(f"{outline_open}{outline_paths[i]}</g>"
                   f"{ear_open}{ear_paths[i]}</g>{inner_paths[i]}")

    # Párpados con el mismo degradado que la cabeza (en coordenadas del lienzo),
    # para que no se note el borde al parpadear.
    lid = ('<defs><radialGradient id="lid" gradientUnits="userSpaceOnUse" '
           'cx="230.7" cy="240" r="181" gradientTransform="translate(230.7 240) '
           'scale(1 0.905) translate(-230.7 -240)">'
           '<stop offset="0" stop-color="#4A3F3D"/><stop offset="1" stop-color="#1C1716"/>'
           '</radialGradient></defs>')
    blink = svg(
        lid +
        '<ellipse cx="202" cy="304" rx="41" ry="40" fill="url(#lid)"/>'
        '<ellipse cx="310" cy="304" rx="41" ry="40" fill="url(#lid)"/>'
        '<g fill="none" stroke="#0B0707" stroke-width="9" stroke-linecap="round">'
        '<path d="M168 302 Q202 330 236 302"/><path d="M276 302 Q310 330 344 302"/></g>'
    )
    return {
        "body": svg(f"{outline_open}{''.join(outline_paths[2:])}</g>"),
        "ear_left": ear(0),
        "ear_right": ear(1),
        "face": svg(face),
        "blink": blink,
    }


if __name__ == "__main__":
    out = HERE / "layers"
    out.mkdir(exist_ok=True)
    for name, text in layers().items():
        (out / f"taquito_{name}.svg").write_text(text, encoding="utf-8")
        print("generado", name)
