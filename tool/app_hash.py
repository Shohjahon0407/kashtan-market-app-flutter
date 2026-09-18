#!/usr/bin/env python3
"""Android SMS Retriever API uchun 11 belgilik app hash — offline hisoblash.

Foydalanish:

    tool/app_hash.py uz.beshkashtan.customer ~/Downloads/deployment_cert.der
    tool/app_hash.py uz.beshkashtan.customer upload.pem

Sertifikatni qayerdan olish:

  * PRODUCTION (SMS'ga AYNAN SHU ketadi) — Play Console → Test and release →
    Setup → App integrity → App signing → "Download app signing certificate".
    Play ilovani o'z kaliti bilan QAYTA imzolaydi, shuning uchun bizdagi
    upload kaliti to'g'ri kelmaydi.
  * upload kaliti (sideload qilingan APK uchun):
        keytool -exportcert -alias <keyAlias> -keystore <storeFile> \\
            -storepass <storePassword> -file upload.der
  * debug kaliti (`flutter run`):
        keytool -exportcert -alias androiddebugkey \\
            -keystore ~/.android/debug.keystore -storepass android \\
            -file debug.der

Natijani serverdagi `.env` ga `SMS_APP_HASH=...` sifatida yozing —
LEKIN avval yangi SMS matnini Eskiz'da qayta tasdiqlating.
"""

import base64
import hashlib
import sys
from pathlib import Path


def der_bytes(path: Path) -> bytes:
    """PEM bo'lsa dekodlaydi, DER bo'lsa o'zini qaytaradi."""
    raw = path.read_bytes()
    if raw.lstrip().startswith(b"-----BEGIN"):
        body = b"".join(
            line.strip()
            for line in raw.splitlines()
            if line.strip() and not line.strip().startswith(b"-----")
        )
        return base64.b64decode(body)
    return raw


def app_hash(package: str, cert_der: bytes) -> str:
    """Google'ning AppSignatureHelper algoritmi.

    Ikki joyda xato qilinadi va ikkalasi ham jimgina noto'g'ri hash beradi:
      * birinchi 9 BAYT olinadi (9 ta base64 belgi emas);
      * standart base64 alifbosi ishlatiladi (URL-safe emas).
    """
    # Signature.toCharsString() == DER baytlarining kichik harfli hex'i.
    signature = cert_der.hex()
    digest = hashlib.sha256(f"{package} {signature}".encode("utf-8")).digest()
    return base64.b64encode(digest[:9]).decode("ascii")[:11]


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    package, cert_path = argv[1], Path(argv[2])
    if not cert_path.is_file():
        print(f"Sertifikat topilmadi: {cert_path}", file=sys.stderr)
        return 1
    print(app_hash(package, der_bytes(cert_path)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
