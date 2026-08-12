#!/usr/bin/env bash
# Generate every iOS and Android launcher icon from one source image.
#
# Usage:  tools/make-icons.sh [source]
#         tools/make-icons.sh packages/wh40k_app/design/icon.svg     (default)
#         tools/make-icons.sh ~/Downloads/icon.png
#
# Accepts an SVG (rendered with rsvg-convert) or any raster sips can read.
# The source should be square and at least 1024x1024. Launcher icons must be
# fully opaque with no rounded corners of their own — both platforms apply
# their own mask, and baking one in produces a visible double corner.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$ROOT/packages/wh40k_app/design/icon.svg}"
APP="$ROOT/packages/wh40k_app"
IOS="$APP/ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID="$APP/android/app/src/main/res"

[ -f "$SRC" ] || { echo "no source at $SRC" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
MASTER="$WORK/master.png"

case "$SRC" in
  *.svg|*.SVG)
    command -v rsvg-convert >/dev/null || {
      echo "rsvg-convert not found — brew install librsvg" >&2; exit 2; }
    rsvg-convert -w 1024 -h 1024 "$SRC" -o "$MASTER"
    ;;
  *)
    sips -s format png "$SRC" --resampleHeightWidth 1024 1024 --out "$MASTER" >/dev/null
    ;;
esac

emit() { # size dest
  sips -s format png "$MASTER" --resampleHeightWidth "$1" "$1" --out "$2" >/dev/null
}

echo "iOS:"
# Names must match Contents.json, which flutter create already wrote.
while read -r size name; do
  emit "$size" "$IOS/$name"
  printf '  %-34s %sx%s\n' "$name" "$size" "$size"
done <<'SIZES'
20 Icon-App-20x20@1x.png
40 Icon-App-20x20@2x.png
60 Icon-App-20x20@3x.png
29 Icon-App-29x29@1x.png
58 Icon-App-29x29@2x.png
87 Icon-App-29x29@3x.png
40 Icon-App-40x40@1x.png
80 Icon-App-40x40@2x.png
120 Icon-App-40x40@3x.png
120 Icon-App-60x60@2x.png
180 Icon-App-60x60@3x.png
76 Icon-App-76x76@1x.png
152 Icon-App-76x76@2x.png
167 Icon-App-83.5x83.5@2x.png
1024 Icon-App-1024x1024@1x.png
SIZES

echo "Android:"
while read -r size dir; do
  emit "$size" "$ANDROID/$dir/ic_launcher.png"
  printf '  %-22s %sx%s\n' "$dir" "$size" "$size"
done <<'SIZES'
48 mipmap-mdpi
72 mipmap-hdpi
96 mipmap-xhdpi
144 mipmap-xxhdpi
192 mipmap-xxxhdpi
SIZES

echo
echo "Done. Rebuild to see it:"
echo "  cd packages/wh40k_app && flutter build ios --simulator --debug"
