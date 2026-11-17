"""PNG-only campaign export with real Flutter screen captures in phone slots.

All photographic creation/edits use imagegen. Native SVG composition embeds
existing QR/logo and rendered Flutter UI; no raster photo editing is performed.
Intermediate vector layout stays in memory; only PNG deliverables are exported.
"""
import base64
import json
from pathlib import Path

import cairosvg
from PIL import Image
import zxingcpp


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "sources"
V2 = ROOT.parent / "delivery-launch-v2-2026-11"
EXPECTED = "https://api.beshkashtan.uz/app/"


def uri(path, mime):
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def export(poster):
    key = poster["id"]
    background = SOURCE / f"{key}-artwork.png"
    with Image.open(background) as image:
        width, height = image.size
    x, y, size = poster["qr"]
    lx, ly, ls = poster["logo"]
    clip = ""
    phone = ""
    if "screen" in poster:
        sx, sy, sw, sh = poster["screen"]
        assert 0 <= sx < sx + sw <= width and 0 <= sy < sy + sh <= height
        screenshot = uri(SOURCE / poster["capture"], "image/png")
        clip = f'<clipPath id="screen"><rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="10"/></clipPath>'
        phone = f'''<g clip-path="url(#screen)">
          <rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" fill="#FFFFFF"/>
          <image x="{sx}" y="{sy}" width="{sw}" height="{sh}"
            preserveAspectRatio="xMidYMid meet" xlink:href="{screenshot}"/>
        </g>'''
    source = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
      width="297mm" height="420mm" viewBox="0 0 {width} {height}">
      <defs>{clip}</defs>
      <rect width="{width}" height="{height}" fill="#04552D"/>
      <image width="{width}" height="{height}" xlink:href="{uri(background, 'image/png')}"/>
      {phone}
      <rect x="{x}" y="{y}" width="{size}" height="{size}" fill="#FFFFFF"/>
      <image x="{x}" y="{y}" width="{size}" height="{size}" xlink:href="{uri(V2 / 'besh-kashtan-app-qr.svg', 'image/svg+xml')}"/>
      <rect x="{lx}" y="{ly}" width="{ls}" height="{ls}" rx="{ls * .16}" fill="#FFFFFF"/>
      <image x="{lx + ls * .04}" y="{ly + ls * .04}" width="{ls * .92}" height="{ls * .92}"
        preserveAspectRatio="xMidYMid meet" xlink:href="{uri(V2 / 'app-logo.png', 'image/png')}"/>
    </svg>'''.encode()
    output = ROOT / f"{key}-reklama.png"
    cairosvg.svg2png(bytestring=source, output_width=3508, output_height=4961, write_to=str(output))
    with Image.open(output) as image:
        decoded = zxingcpp.read_barcodes(image.convert("RGB"))
    assert len(decoded) == 1 and decoded[0].text == EXPECTED, key
    print(f"{key}: 3508×4961 PNG, real UI + QR verified")


def main():
    for poster in json.loads((SOURCE / "placements.json").read_text()):
        export(poster)


if __name__ == "__main__":
    main()
