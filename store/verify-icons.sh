#!/usr/bin/env bash
# Check a built app for the icons App Store Connect requires, before uploading.
#
# Apple rejected an upload on 2026-08-23 with four "Missing required icon file"
# errors — 120x120, 152x152, 167x167 and the 1024 marketing icon — for a
# project whose asset catalog contains all four. An archive can be built
# without them (a stale DerivedData is the usual reason) and the only place
# that shows is the upload. This reads the built bundle rather than the
# catalog, so it answers the question Apple is actually asking.
#
#   store/verify-icons.sh                                  # the last release build
#   store/verify-icons.sh path/to/Runner.app
#   store/verify-icons.sh path/to/Structor.ipa
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TARGET=${1:-$ROOT/packages/wh40k_app/build/ios/iphoneos/Runner.app}
WORK=$(mktemp -d)
INFO=$(mktemp)
trap 'rm -rf "$WORK" "$INFO"' EXIT

if [ ! -e "$TARGET" ]; then
  echo "no build at $TARGET" >&2
  echo "build one with:  cd packages/wh40k_app && flutter build ios --release --no-codesign" >&2
  exit 1
fi

# An .ipa is a zip with Payload/<name>.app inside.
case "$TARGET" in
  *.ipa)
    unzip -q "$TARGET" -d "$WORK"
    TARGET=$(find "$WORK/Payload" -maxdepth 1 -name '*.app' | head -1)
    [ -n "$TARGET" ] || { echo "no .app inside that .ipa" >&2; exit 1; }
    ;;
esac

CAR="$TARGET/Assets.car"
if [ ! -f "$CAR" ]; then
  echo "FAIL  no Assets.car in $(basename "$TARGET") — the catalog was not compiled in" >&2
  exit 1
fi

# CFBundleIconName is what ties the bundle to the catalog's icon set. Without
# it the icons can be present and still not be found.
NAME=$(/usr/libexec/PlistBuddy -c \
        "Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName" \
        "$TARGET/Info.plist" 2>/dev/null || echo "")
if [ -z "$NAME" ]; then
  echo "FAIL  Info.plist has no CFBundleIconName" >&2
  exit 1
fi
echo "  bundle:           $(basename "$TARGET")"
echo "  CFBundleIconName: $NAME"
echo

# The listing goes to a file rather than a pipe, so the reader's own heredoc
# cannot take stdin from under it.
xcrun assetutil --info "$CAR" >"$INFO" 2>/dev/null

python3 "$ROOT/store/icon_sizes.py" "$NAME" "$INFO"
