#!/usr/bin/env bash
# Generate every iOS and Android launcher icon from one source image.
#
# Usage:  tools/make-icons.sh [source]
#         tools/make-icons.sh packages/wh40k_app/design/icon-source.png  (default)
#         tools/make-icons.sh ~/Downloads/icon.png
#
# Accepts an SVG (rendered with rsvg-convert) or any raster sips can read.
# The source should be square and at least 1024x1024. Launcher icons must be
# fully opaque with no rounded corners of their own — both platforms apply
# their own mask, and baking one in produces a visible double corner.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$ROOT/packages/wh40k_app/design/icon-source.png}"
APP="$ROOT/packages/wh40k_app"
IOS="$APP/ios/Runner/Assets.xcassets/AppIcon.appiconset"
# The Android project is a repository of its own now (DESIGN.md §3.24), so
# the launcher icons are written into whichever sibling checkout is there.
# Absent, the iOS half still runs: this generates icons, and one platform's
# icons are worth generating without the other's.
ANDROID=""
for at in "$ROOT/../Structor_android" "$ROOT/../Structor_Android"; do
  [ -d "$at/android/app/src/main/res" ] && \
    ANDROID="$at/android/app/src/main/res" && break
done

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

if [ -z "$ANDROID" ]; then
  echo "no Structor_android checkout beside this one — iOS icons only" >&2
  exit 0
fi

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

# Android 8 and later draws a launcher icon from two layers and applies its
# own mask to them, so the square above is only the fallback for Android 7.
# The foreground has to sit inside the middle 66% — the corners and edges are
# cropped by whatever shape the launcher uses, and a helmet drawn to the edge
# of the square loses its crest to a circle.
#
# The background is the source's own field colour, taken from its corner, so
# the 66% square and the field behind it are the same navy and the seam
# between the two layers cannot be seen.
#
# The third layer is the themed icon Android 13 tints to the wallpaper: the
# same art as a stencil, keyed off which of the two colours each pixel is
# nearer to.
echo "Android adaptive:"
python3 - "$MASTER" "$ANDROID" <<'ADAPTIVE'
import sys
try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit('Pillow not found — pip3 install Pillow')

master, res = sys.argv[1], sys.argv[2]
art = Image.open(master).convert('RGBA')

# The field colour, taken as the median of the border rather than one corner:
# the source is not perfectly flat, and a colour that is a shade off shows up
# as a visible square where the two layers meet.
edge = ([art.getpixel((x, 0)) for x in range(art.width)] +
        [art.getpixel((x, art.height - 1)) for x in range(art.width)] +
        [art.getpixel((0, y)) for y in range(art.height)] +
        [art.getpixel((art.width - 1, y)) for y in range(art.height)])
field = tuple(sorted(c[i] for c in edge)[len(edge) // 2] for i in range(3))

# The other colour in a two-tone icon: the pixel furthest from the field.
def distance(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b))

small = art.resize((64, 64))
ink = max((p[:3] for p in small.getdata()), key=lambda p: distance(p, field))

# And then cut it away entirely. Filling from the border rather than keying
# on the colour keeps the navy *inside* the helmet — its visor slots, the
# lines in the crest — which a colour key would have punched through.
ImageDraw.floodfill(art, (0, 0), (0, 0, 0, 0), thresh=70)
ImageDraw.floodfill(art, (art.width - 1, art.height - 1), (0, 0, 0, 0),
                    thresh=70)

INSET = 0.66
for size, folder in [(108, 'mdpi'), (162, 'hdpi'), (216, 'xhdpi'),
                     (324, 'xxhdpi'), (432, 'xxxhdpi')]:
    inner = round(size * INSET)
    scaled = art.resize((inner, inner), Image.LANCZOS)

    foreground = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    at = (size - inner) // 2
    foreground.paste(scaled, (at, at))
    foreground.save(f'{res}/mipmap-{folder}/ic_launcher_foreground.png',
                    optimize=True)

    stencil = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pixels = stencil.load()
    source = scaled.load()
    for y in range(inner):
        for x in range(inner):
            r, g, b, a = source[x, y]
            near_ink = a > 128 and \
                distance((r, g, b), ink) < distance((r, g, b), field)
            pixels[at + x, at + y] = (255, 255, 255, 255 if near_ink else 0)
    stencil.save(f'{res}/mipmap-{folder}/ic_launcher_monochrome.png',
                 optimize=True)
    print('  %-22s %sx%s' % ('mipmap-' + folder, size, size))

colour = '#%02X%02X%02X' % field
with open(f'{res}/values/ic_launcher_background.xml', 'w') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <!-- The field the source art is drawn on, so the adaptive\n'
            '         icon\'s two layers meet without a seam. -->\n'
            f'    <color name="ic_launcher_background">{colour}</color>\n'
            '</resources>\n')
print('  background', colour)
ADAPTIVE

echo
echo "Done. Rebuild to see it:"
echo "  cd packages/wh40k_app && flutter build ios --simulator --debug"
