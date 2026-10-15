#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$PROJECT_DIR/android"
KEY_PROPERTIES_FILE="$ANDROID_DIR/key.properties"
GOOGLE_SERVICES_FILE="$ANDROID_DIR/app/google-services.json"
PLAY_ICON_FILE="$PROJECT_DIR/docs/play-store/assets/app-icon-512.png"
FEATURE_GRAPHIC_FILE="$PROJECT_DIR/docs/play-store/assets/feature-graphic-1024x500.png"
BACKEND_ORIGIN_VALUE="${BACKEND_ORIGIN:-https://api.beshkashtan.uz}"
MAPBOX_TOKEN_VALUE="${MAPBOX_ACCESS_TOKEN:-}"

log() {
  printf '\n[%s]\n' "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command is missing: $1"
}

for command_name in flutter java python3 unzip readelf sha256sum jarsigner ffprobe; do
  require_command "$command_name"
done

[[ "$BACKEND_ORIGIN_VALUE" == https://* ]] || \
  fail "BACKEND_ORIGIN must use HTTPS for a Play release."
# Mapbox token — production xarita uchun tavsiya etilgan yo'l. Token hali
# olinmagan bo'lsa ALLOW_OSM_TILES=1 bilan ataylab OSM zaxirasida qurish
# mumkin (ilova tokensiz o'zi OSM'ga tushadi). Bu VAQTINCHA: OSM tile-server
# SLA bermaydi; caching, attribution va identifikatsiya siyosati bajarilishi shart.
MAP_PROVIDER="Mapbox"
if [[ "$MAPBOX_TOKEN_VALUE" == pk.* && ${#MAPBOX_TOKEN_VALUE} -ge 20 ]]; then
  :
elif [[ "${ALLOW_OSM_TILES:-}" == "1" ]]; then
  # Release yozuvi haqiqatni ko'rsatsin: bu build OSM tile'lari bilan ketadi.
  MAP_PROVIDER="OpenStreetMap (vaqtinchalik zaxira, Mapbox tokeni yo'q)"
  printf 'WARNING: Building WITHOUT a Mapbox token — maps use the public OSM
' >&2
  printf 'WARNING: tile server (temporary; add MAPBOX_ACCESS_TOKEN before scale).
' >&2
else
  fail "Set a restricted public MAPBOX_ACCESS_TOKEN (pk.*) before building, or pass ALLOW_OSM_TILES=1 to accept the temporary OSM fallback."
fi

cd "$PROJECT_DIR"

log "Validate signing and Firebase configuration"
python3 - "$PROJECT_DIR" "$KEY_PROPERTIES_FILE" "$GOOGLE_SERVICES_FILE" <<'PY'
import json
import os
import stat
import sys
from pathlib import Path

project_dir = Path(sys.argv[1]).resolve()
properties_path = Path(sys.argv[2])
firebase_path = Path(sys.argv[3])

if not properties_path.is_file():
    raise SystemExit("android/key.properties is required for a release build")

properties = {}
for raw_line in properties_path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith(('#', '!')):
        continue
    key, separator, value = line.partition('=')
    if not separator:
        key, separator, value = line.partition(':')
    if separator:
        properties[key.strip()] = value.strip()

required = ("storeFile", "storePassword", "keyAlias", "keyPassword")
missing = [key for key in required if not properties.get(key)]
if missing:
    raise SystemExit("Missing release signing properties: " + ", ".join(missing))

store_file = Path(properties["storeFile"])
if not store_file.is_absolute():
    store_file = project_dir / "android" / store_file
store_file = store_file.resolve()
if not store_file.is_file():
    raise SystemExit(f"Upload keystore does not exist: {store_file}")

if os.name == "posix":
    mode = stat.S_IMODE(properties_path.stat().st_mode)
    if mode & 0o077:
        raise SystemExit("android/key.properties must not be group/world readable; use chmod 600")

if not firebase_path.is_file():
    raise SystemExit("android/app/google-services.json is required")
firebase = json.loads(firebase_path.read_text(encoding="utf-8"))
project_id = firebase.get("project_info", {}).get("project_id")
packages = {
    client.get("client_info", {})
    .get("android_client_info", {})
    .get("package_name")
    for client in firebase.get("client", [])
}
if project_id != "kashtan-5feea":
    raise SystemExit(f"Unexpected Firebase project: {project_id!r}")
if "uz.beshkashtan.customer" not in packages:
    raise SystemExit("Firebase config has no uz.beshkashtan.customer client")

print("Signing properties, upload keystore and Firebase package are present.")
PY

[[ -f "$PLAY_ICON_FILE" ]] || fail "Play Store 512x512 icon is missing."
[[ -f "$FEATURE_GRAPHIC_FILE" ]] || fail "Play Store 1024x500 feature graphic is missing."
ICON_DIMENSIONS="$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=s=x:p=0 "$PLAY_ICON_FILE")"
FEATURE_DIMENSIONS="$(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height -of csv=s=x:p=0 "$FEATURE_GRAPHIC_FILE")"
[[ "$ICON_DIMENSIONS" == "512x512" ]] || \
  fail "Play Store icon must be 512x512, got $ICON_DIMENSIONS."
[[ "$(stat -c %s "$PLAY_ICON_FILE")" -lt 1048576 ]] || \
  fail "Play Store icon must be smaller than 1 MB."
[[ "$FEATURE_DIMENSIONS" == "1024x500" ]] || \
  fail "Feature graphic must be 1024x500, got $FEATURE_DIMENSIONS."

VERSION="$(python3 - <<'PY'
import re
from pathlib import Path

match = re.search(r"(?m)^version:\s*([^\s]+)", Path("pubspec.yaml").read_text())
if not match:
    raise SystemExit("pubspec.yaml version is missing")
print(match.group(1))
PY
)"
SAFE_VERSION="${VERSION//+/-}"
SYMBOLS_DIR="$PROJECT_DIR/build/play-symbols/$SAFE_VERSION"
ARTIFACTS_DIR="$PROJECT_DIR/build/play-release/$SAFE_VERSION"

log "Resolve Flutter dependencies"
flutter pub get

log "Static analysis"
flutter analyze --no-pub

log "Flutter tests"
flutter test --no-pub --concurrency=2

log "Android release lint"
(
  cd "$ANDROID_DIR"
  ./gradlew :app:lintRelease
)

mkdir -p "$SYMBOLS_DIR"

BUILD_DEFINES=(
  "--dart-define=APP_FLAVOR=prod"
  "--dart-define=BACKEND_ORIGIN=$BACKEND_ORIGIN_VALUE"
  "--dart-define=MAPBOX_ACCESS_TOKEN=$MAPBOX_TOKEN_VALUE"
  "--dart-define=VERBOSE_NETWORK_LOG=false"
  "--dart-define=PAYME_ENABLED=false"
)
if [[ "${ALLOW_OSM_TILES:-}" == "1" ]]; then
  BUILD_DEFINES+=("--dart-define=ALLOW_OSM_TILES=true")
fi

log "Signed release AAB"
flutter build appbundle \
  --release \
  --no-pub \
  --split-debug-info="$SYMBOLS_DIR" \
  "${BUILD_DEFINES[@]}"

log "Signed release APK for device and 16 KB checks"
flutter build apk \
  --release \
  --no-pub \
  --split-debug-info="$SYMBOLS_DIR" \
  "${BUILD_DEFINES[@]}"

AAB_SOURCE="$PROJECT_DIR/build/app/outputs/bundle/release/app-release.aab"
APK_SOURCE="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
[[ -f "$AAB_SOURCE" ]] || fail "Release AAB was not generated."
[[ -f "$APK_SOURCE" ]] || fail "Release APK was not generated."

SDK_DIR="$(python3 - "$ANDROID_DIR/local.properties" <<'PY'
import sys
from pathlib import Path

for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    if line.startswith("sdk.dir="):
        print(line.split("=", 1)[1].replace(r"\:", ":").replace(r"\\", "\\"))
        break
else:
    raise SystemExit("sdk.dir is missing from android/local.properties")
PY
)"
BUILD_TOOLS_DIR="$(find "$SDK_DIR/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
AAPT="$BUILD_TOOLS_DIR/aapt"
APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"
[[ -x "$AAPT" && -x "$APKSIGNER" && -x "$ZIPALIGN" ]] || \
  fail "aapt/apksigner/zipalign are unavailable in the latest Android build-tools."

BADGING="$($AAPT dump badging "$APK_SOURCE")"
PACKAGE_NAME="$(printf '%s\n' "$BADGING" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
TARGET_SDK="$(printf '%s\n' "$BADGING" | sed -n "s/^targetSdkVersion:'\([^']*\)'.*/\1/p")"
VERSION_CODE="$(printf '%s\n' "$BADGING" | sed -n "s/^package:.*versionCode='\([^']*\)'.*/\1/p")"
[[ "$PACKAGE_NAME" == "uz.beshkashtan.customer" ]] || \
  fail "Unexpected APK package: $PACKAGE_NAME"
[[ "$TARGET_SDK" == "36" ]] || fail "Expected targetSdkVersion 36, got $TARGET_SDK"

log "APK signature and alignment"
$APKSIGNER verify --verbose --print-certs "$APK_SOURCE"
$ZIPALIGN -c -P 16 -v 4 "$APK_SOURCE" >/dev/null
jarsigner -verify "$AAB_SOURCE" >/dev/null

ELF_TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf -- "$ELF_TEMP_DIR"
}
trap cleanup EXIT
unzip -q "$APK_SOURCE" 'lib/arm64-v8a/*.so' 'lib/x86_64/*.so' -d "$ELF_TEMP_DIR"
python3 - "$ELF_TEMP_DIR" <<'PY'
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
libraries = sorted(root.rglob("*.so"))
if not libraries:
    raise SystemExit("No 64-bit native libraries were found in the APK")

bad = []
for library in libraries:
    output = subprocess.check_output(
        ["readelf", "-lW", str(library)], text=True, errors="replace"
    )
    for line in output.splitlines():
        columns = line.split()
        if not columns or columns[0] != "LOAD":
            continue
        alignment = int(columns[-1], 0)
        if alignment < 0x4000:
            bad.append(f"{library.name}: {columns[-1]}")
if bad:
    raise SystemExit("ELF segments below 16 KB alignment:\n" + "\n".join(bad))
print(f"Verified 16 KB ELF alignment for {len(libraries)} 64-bit libraries.")
PY

mkdir -p "$ARTIFACTS_DIR"
AAB_TARGET="$ARTIFACTS_DIR/besh-kashtan-$SAFE_VERSION.aab"
APK_TARGET="$ARTIFACTS_DIR/besh-kashtan-$SAFE_VERSION.apk"
cp "$AAB_SOURCE" "$AAB_TARGET"
cp "$APK_SOURCE" "$APK_TARGET"

MAPPING_SOURCE="$PROJECT_DIR/build/app/outputs/mapping/release/mapping.txt"
if [[ -f "$MAPPING_SOURCE" ]]; then
  cp "$MAPPING_SOURCE" "$ARTIFACTS_DIR/r8-mapping.txt"
fi

$APKSIGNER verify --print-certs "$APK_TARGET" > "$ARTIFACTS_DIR/certificate.txt"
sha256sum "$AAB_TARGET" "$APK_TARGET" > "$ARTIFACTS_DIR/SHA256SUMS"
printf '%s\n' \
  'app=Besh Kashtan' \
  "package=$PACKAGE_NAME" \
  "version=$VERSION" \
  "version_code=$VERSION_CODE" \
  "target_sdk=$TARGET_SDK" \
  'payme_enabled=false' \
  'firebase_project=kashtan-5feea' \
  "map_provider=$MAP_PROVIDER" \
  "backend_origin=$BACKEND_ORIGIN_VALUE" \
  > "$ARTIFACTS_DIR/release-manifest.txt"

log "Play release gate passed"
printf 'Artifacts: %s\n' "$ARTIFACTS_DIR"
printf 'AAB: %s\n' "$AAB_TARGET"
printf 'APK: %s\n' "$APK_TARGET"
printf 'Dart symbols: %s\n' "$SYMBOLS_DIR"
