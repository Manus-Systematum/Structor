#!/usr/bin/env bash
# Capture one App Store screenshot from a booted simulator.
#
# Navigate the simulator to the screen you want, then run this with the name
# of the shot. It sets Apple's 9:41 status bar first, so every file in the set
# matches, and writes the device's native resolution with no scaling — which
# for iPhone 17 Pro Max is 1320x2868, exactly the 6.9-inch size the store
# wants, and for iPad Pro 13-inch is 2064x2752.
#
#   store/screenshots/capture.sh 02-editor
#   store/screenshots/capture.sh 03-turn
#
# Override the device with DEVICE=, by name or UDID:
#   DEVICE="iPad Pro 13-inch (M5)" store/screenshots/capture.sh 01-armies
set -euo pipefail

DEVICE=${DEVICE:-iPhone 17 Pro Max}
NAME=${1:-}
DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ -z "$NAME" ]; then
  echo "usage: $(basename "$0") <name>    e.g. 02-editor" >&2
  echo >&2
  echo "the set, in the order that explains the app:" >&2
  echo "  01-armies      the army list" >&2
  echo "  02-editor      Edit army, showing 995/1000 and the detachments" >&2
  echo "  03-turn        a phase with its stratagems, one expanded" >&2
  echo "  04-setup       the mission with the deployment map drawn" >&2
  echo "  05-objectives  primary and secondary scoring, running total" >&2
  exit 64
fi

# Resolve a name to a UDID, and refuse a device that is not booted rather than
# silently shooting the wrong one.
UDID=$(xcrun simctl list devices booted \
  | awk -v want="$DEVICE" '
      index($0, want) { if (match($0, /[0-9A-F-]{36}/)) print substr($0, RSTART, RLENGTH) }' \
  | head -1)

if [ -z "$UDID" ]; then
  echo "no booted device matching \"$DEVICE\"." >&2
  echo "booted now:" >&2
  xcrun simctl list devices booted | grep -i booted | sed 's/^ */  /' >&2
  echo "boot one with:  xcrun simctl boot \"$DEVICE\"" >&2
  exit 1
fi

# Apple's own screenshots read 9:41 with full bars. Harmless to repeat.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --batteryState charged --batteryLevel 100 2>/dev/null

# The 6.9-inch set is the required one; anything else gets its size in the
# filename so a wrong-sized file cannot be uploaded by accident.
OUT="$DIR/$NAME-6.9.png"
xcrun simctl io "$UDID" screenshot "$OUT" >/dev/null 2>&1

SIZE=$(python3 -c "from PIL import Image;im=Image.open('$OUT');print('%dx%d'%im.size)" 2>/dev/null || echo unknown)
case "$SIZE" in
  1320x2868|1290x2796) NOTE="6.9-inch, the required iPhone size" ;;
  2064x2752)           mv "$OUT" "$DIR/$NAME-ipad13.png"; OUT="$DIR/$NAME-ipad13.png"
                       NOTE="13-inch iPad, required while the app ships for iPad" ;;
  *)                   mv "$OUT" "$DIR/$NAME-$SIZE.png"; OUT="$DIR/$NAME-$SIZE.png"
                       NOTE="NOT an App Store size — shoot on iPhone 17 Pro Max instead" ;;
esac

echo "$(basename "$OUT")  $SIZE  — $NOTE"
