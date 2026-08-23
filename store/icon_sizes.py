#!/usr/bin/env python3
"""Report which App Store required icon sizes a compiled asset catalog holds.

Called by verify-icons.sh with the icon set's name and a file holding
`xcrun assetutil --info`'s JSON. Separate from the shell script because the
reader must not share stdin with it.
"""
import json
import sys

# Every size App Store Connect refuses an upload for, in its own wording.
REQUIRED = [
    (120, "iPhone 120x120 (60pt @2x)"),
    (180, "iPhone 180x180 (60pt @3x)"),
    (152, "iPad 152x152 (76pt @2x)"),
    (167, "iPad Pro 167x167 (83.5pt @2x)"),
    (1024, "marketing 1024x1024"),
]


def main() -> int:
    name, path = sys.argv[1], sys.argv[2]
    with open(path) as f:
        entries = json.load(f)

    sizes = {
        entry.get("PixelWidth")
        for entry in entries
        if isinstance(entry, dict)
        and name in str(entry.get("Name", ""))
        and entry.get("PixelWidth")
    }

    missing = [what for px, what in REQUIRED if px not in sizes]
    for px, what in REQUIRED:
        print("  %-32s %s" % (what, "present" if px in sizes else "MISSING"))

    if missing:
        print("\nFAIL  %d required icon(s) absent from the built bundle."
              % len(missing))
        print("Rebuild after clearing the build cache:")
        print("  rm -rf ~/Library/Developer/Xcode/DerivedData/*")
        print("  cd packages/wh40k_app && flutter clean && flutter build ipa")
        return 1

    print("\nOK  every required icon is in the bundle.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
