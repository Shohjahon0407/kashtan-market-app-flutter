"""Build a self-contained vector poster, print PDF and raster preview.

Photography was generated with imagegen. Typography and the real, machine-
verified QR remain deterministic/vector, not invented by an image model.
Requires cairosvg (use the isolated QR tooling environment).
"""
import base64
from pathlib import Path

import cairosvg


def data_uri(path, mime):
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def main():
    folder = Path(__file__).resolve().parent
    source = (folder / "poster-template.svg").read_text()
    source = source.replace("__HERO_DATA_URI__", data_uri(folder / "ofiyat-food-hero.png", "image/png"))
    source = source.replace("__QR_DATA_URI__", data_uri(folder / "besh-kashtan-app-qr.svg", "image/svg+xml"))
    svg = folder / "ofiyat-app-banner-A3.svg"
    svg.write_text(source)
    cairosvg.svg2pdf(bytestring=source.encode(), write_to=str(folder / "ofiyat-app-banner-A3.pdf"))
    cairosvg.svg2png(bytestring=source.encode(), output_width=1754, output_height=2480,
                    write_to=str(folder / "ofiyat-app-banner-preview.png"))
    cairosvg.svg2png(bytestring=source.encode(), output_width=3508, output_height=4961,
                    write_to=str(folder / "ofiyat-app-banner-A3-300dpi.png"))
    print("Created self-contained A3 SVG, PDF, preview and 3508×4961 PNG")


if __name__ == "__main__":
    main()
