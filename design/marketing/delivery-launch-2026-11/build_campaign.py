"""Four A3 delivery-launch ads with generated photos and a real vector QR.

Run using the isolated QR tools environment (CairoSVG + Pillow installed).
This is vector page layout/export, not generative QR or raster photo editing.
The poster's SVG/PDF is self-contained. No application/server state is changed.
"""
import base64
from html import escape
from pathlib import Path

import cairosvg


ROOT = Path(__file__).resolve().parent
URL = "https://api.beshkashtan.uz/app/"
POSTERS = [
    {
        "id": "1005", "brand": "1005 XIL MAHSULOT", "brand_size": 163,
        "descriptor": "Uy-ro‘zg‘or va kundalik ehtiyojlar uchun",
        "color": "#087C5C", "secondary": "#D8F5E6",
        "copy": ["Kerakli mahsulotlarni ilovadan tanlang.",
                 "Buyurtmangizni manzilingizga yetkazib beramiz."],
        "footer": "1005 xil mahsulot · Besh Kashtan ilovasida",
    },
    {
        "id": "pokiza-halol", "brand": "POKIZA HALOL", "brand_size": 192,
        "descriptor": "Shashlik va marinovka",
        "color": "#065C45", "secondary": "#D8F5E6",
        "copy": ["Shashlik va marinovkani ilovadan buyurtma qiling.",
                 "Dona yoki kilogramm — miqdorni o‘zingiz tanlang."],
        "footer": "Pokiza Halol · Besh Kashtan ilovasida",
    },
    {
        "id": "gosht", "brand": "GO‘SHT DO‘KONI", "brand_size": 186,
        "descriptor": "Go‘sht mahsulotlari — endi ilovada",
        "color": "#8C2435", "secondary": "#FBE5E8",
        "copy": ["Go‘sht mahsulotlarini telefoningizdan tanlang.",
                 "Buyurtmangizni manzilingizga yetkazib beramiz."],
        "footer": "Go‘sht do‘koni · Besh Kashtan ilovasida",
    },
    {
        "id": "umumiy", "brand": "BESH KASHTAN", "brand_size": 192,
        "descriptor": "Turli do‘konlar. Bitta ilova.",
        "color": "#087C5C", "secondary": "#D8F5E6",
        "copy": ["Uy-ro‘zg‘or, taomlar, shashlik va go‘sht — bir ilovada.",
                 "Tanlang va manzilingizga buyurtma qiling."],
        "footer": "1005 xil mahsulot · Ofiyat · Pokiza Halol · Go‘sht do‘koni",
    },
]


def uri(path, mime):
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def text(x, y, size, value, *, fill="#111827", weight="400", anchor="start"):
    return (f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}">{escape(value)}</text>')


def make_poster(poster):
    key = poster["id"]
    color = poster["color"]
    qr = uri(ROOT / "besh-kashtan-app-qr.svg", "image/svg+xml")
    hero = uri(ROOT / f"{key}-hero.png", "image/png")
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="297mm" height="420mm" viewBox="0 0 2970 4200">',
        f'<title>{escape(poster["brand"])} — yetkazib berish xizmati ishga tushdi</title>',
        '<desc>Besh Kashtan ilovasi reklamasi, A3. Haqiqiy QR Android va iPhone uchun.</desc>',
        '<defs><clipPath id="photo"><rect x="160" y="1320" width="2650" height="1325" rx="70"/></clipPath></defs>',
        '<rect width="2970" height="4200" fill="#FFFFFF"/>',
        f'<rect x="160" y="150" width="580" height="100" rx="50" fill="{color}"/>',
        '<g font-family="DejaVu Sans, sans-serif">',
        text(450, 217, 46, "YANGI XIZMAT", fill="#FFFFFF", weight="700", anchor="middle"),
        text(2810, 217, 43, "BESH KASHTAN ILOVASIDA", fill=color, weight="700", anchor="end"),
        text(160, 468, poster["brand_size"], poster["brand"], fill=color, weight="700"),
        text(166, 575, 62, poster["descriptor"], fill="#374151"),
        text(160, 826, 166, "Yetkazib berish", weight="700"),
        text(160, 1020, 146, "xizmati ishga tushdi!", weight="700"),
        text(166, 1153, 59, poster["copy"][0], fill="#374151"),
        text(166, 1243, 59, poster["copy"][1], fill="#374151"),
        f'<image x="160" y="1320" width="2650" height="1325" clip-path="url(#photo)" '
        f'preserveAspectRatio="xMidYMid meet" xlink:href="{hero}"/>',
        text(1485, 2760, 49, "TANLANG  ·  BUYURTMA QILING  ·  QABUL QILING", fill=color, weight="700", anchor="middle"),
        f'<rect x="160" y="2850" width="2650" height="1090" rx="80" fill="{color}"/>',
        '<rect x="260" y="2950" width="960" height="880" rx="36" fill="#FFFFFF"/>',
        f'<image x="330" y="2970" width="820" height="820" xlink:href="{qr}"/>',
        text(1360, 3076, 94, "Ilovani hoziroq", fill="#FFFFFF", weight="700"),
        text(1360, 3194, 94, "yuklab oling!", fill="#FFFFFF", weight="700"),
        text(1360, 3337, 59, "QR kodni skanerlang.", fill="#FFFFFF"),
        text(1360, 3425, 59, "Telefoningizdan buyurtma qiling.", fill="#FFFFFF"),
        '<line x1="1360" y1="3500" x2="2680" y2="3500" stroke="#FFFFFF" stroke-opacity=".4" stroke-width="2"/>',
        text(1360, 3607, 57, "Google Play · App Store", fill="#FFFFFF", weight="700"),
        text(1360, 3690, 49, "Android va iPhone uchun", fill="#FFFFFF"),
        text(1360, 3795, 42, "api.beshkashtan.uz/app/", fill="#FFFFFF"),
        text(1485, 4060, 42, poster["footer"], fill="#374151", weight="700", anchor="middle"),
        '</g></svg>',
    ]
    return "\n".join(parts)


def main():
    for poster in POSTERS:
        key = poster["id"]
        source = make_poster(poster).encode()
        (ROOT / f"{key}-banner-A3.svg").write_bytes(source)
        cairosvg.svg2pdf(bytestring=source, write_to=str(ROOT / f"{key}-banner-A3.pdf"))
        cairosvg.svg2png(bytestring=source, output_width=1404, output_height=1984,
                        write_to=str(ROOT / f"{key}-preview.png"))
        cairosvg.svg2png(bytestring=source, output_width=3508, output_height=4961,
                        write_to=str(ROOT / f"{key}-banner-A3-300dpi.png"))
        print(f"Exported {key}: SVG / A3 PDF / preview / 3508×4961 PNG")


if __name__ == "__main__":
    main()
