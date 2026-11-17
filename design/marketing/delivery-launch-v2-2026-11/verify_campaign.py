"""Verify actual QR contents after final page composition and PDF export."""
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image
import zxingcpp


ROOT = Path(__file__).resolve().parent
EXPECTED = "https://api.beshkashtan.uz/app/"


def verify(path):
    with Image.open(path) as image:
        decoded = zxingcpp.read_barcodes(image.convert("RGB"))
    assert len(decoded) == 1 and decoded[0].text == EXPECTED, (str(path), decoded)


def main():
    posters = json.loads((ROOT / "placements.json").read_text())
    with tempfile.TemporaryDirectory(prefix="campaign-v2-check-") as temporary:
        for poster in posters:
            key = poster["id"]
            verify(ROOT / f"{key}-preview.png")
            verify(ROOT / f"{key}-banner-A3-300dpi.png")
            pdf = ROOT / f"{key}-banner-A3.pdf"
            info = subprocess.check_output(["pdfinfo", str(pdf)], text=True)
            assert "(A3)" in info, (key, info)
            prefix = Path(temporary) / key
            subprocess.run(["pdftoppm", "-f", "1", "-singlefile", "-scale-to", "1700", "-png",
                            str(pdf), str(prefix)], check=True)
            verify(Path(str(prefix) + ".png"))
            print(f"{key}: PNG preview, large PNG, A3 PDF rendered QR — PASS")
    print(f"{len(posters) * 3} independent QR decode checks passed. Physical-phone/print proof still required.")


if __name__ == "__main__":
    main()
