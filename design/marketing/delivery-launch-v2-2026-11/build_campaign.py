"""Export generated green/yellow campaign artwork with exact QR and app logo.

The image-generation tool creates the actual full-page photographic design.
This SVG layout places the existing real QR/icon into deliberately blank slots;
it never paints, retouches or generatively reconstructs photos or QR modules.
"""
import base64
import json
from html import escape
from pathlib import Path

import cairosvg
from PIL import Image


ROOT = Path(__file__).resolve().parent


def uri(path, mime):
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def main():
    placements = json.loads((ROOT / "placements.json").read_text())
    qr = uri(ROOT / "besh-kashtan-app-qr.svg", "image/svg+xml")
    logo = uri(ROOT / "app-logo.png", "image/png")
    for poster in placements:
        key = poster["id"]
        background = ROOT / f"{key}-artwork.png"
        with Image.open(background) as photo:
            width, height = photo.size
        x, y, size = poster["qr"]
        lx, ly, ls = poster["logo"]
        assert 0 <= x < x + size <= width and 0 <= y < y + size <= height
        assert 0 <= lx < lx + ls <= width and 0 <= ly < ly + ls <= height
        source = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
          width="297mm" height="420mm" viewBox="0 0 {width} {height}">
          <title>{escape(poster["title"])} — Besh Kashtan, yetkazib berish reklamasi</title>
          <desc>AI-created campaign artwork, existing app logo and independently verified vector QR.
            QR: https://api.beshkashtan.uz/app/</desc>
          <rect width="{width}" height="{height}" fill="#04552D"/>
          <image width="{width}" height="{height}" xlink:href="{uri(background, 'image/png')}"/>
          <rect x="{x}" y="{y}" width="{size}" height="{size}" fill="#FFFFFF"/>
          <image x="{x}" y="{y}" width="{size}" height="{size}" xlink:href="{qr}"/>
          <rect x="{lx}" y="{ly}" width="{ls}" height="{ls}" rx="{ls * .16}" fill="#FFFFFF"/>
          <image x="{lx + ls * .04}" y="{ly + ls * .04}" width="{ls * .92}" height="{ls * .92}"
            preserveAspectRatio="xMidYMid meet" xlink:href="{logo}"/>
        </svg>'''
        source = source.encode()
        (ROOT / f"{key}-banner-A3.svg").write_bytes(source)
        cairosvg.svg2pdf(bytestring=source, write_to=str(ROOT / f"{key}-banner-A3.pdf"))
        cairosvg.svg2png(bytestring=source, output_width=1404, output_height=1984,
                        write_to=str(ROOT / f"{key}-preview.png"))
        cairosvg.svg2png(bytestring=source, output_width=3508, output_height=4961,
                        write_to=str(ROOT / f"{key}-banner-A3-300dpi.png"))
        print(f"Exported {key}: A3 SVG/PDF, preview and 3508×4961 PNG")


if __name__ == "__main__":
    main()
