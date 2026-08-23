# Capturing store screenshots

The recipe, because working it out took an hour and none of it is obvious.

**Sizes.** `xcrun simctl io <udid> screenshot` produces the device's native
resolution, and iPhone 17 Pro Max gives **1320 × 2868** — exactly the 6.9-inch
size the App Store requires. iPad Pro 13-inch gives 2064 × 2752, the other
required set while the app ships for iPad. No scaling or cropping is needed, so
never edit the files.

**Getting a real army in.** A screenshot of an empty app describes the app
worse than a sentence does, and building a list by tapping is an afternoon. The
import screen takes a pasted list, so:

```bash
# The simulator pasteboard reads its input as MacRoman, so UTF-8 goes in as
# mojibake: "•" arrives as ",Ä¢" and "Shas'ui" as "Shas,Äôui". Convert first.
iconv -f UTF-8 -t MACROMAN packages/wh40k_core/test/fixtures/war_organ_incursion_1000.txt \
  | xcrun simctl pbcopy <udid>
```

Then in the app: the download icon on the army list → long-press the paste
field → Paste → Import → SAVE. The list resolves to *6 units · 8 entries ·
2 attachments · 995 points — matches the printed total*.

**Moving it between devices.** The army lives in one SQLite file, so it does
not have to be imported twice:

```bash
SRC=$(xcrun simctl get_app_container <from-udid> dev.structor.app data)
DST=$(xcrun simctl get_app_container <to-udid> dev.structor.app data)
rsync -a "$SRC/Documents/" "$DST/Documents/"
```

The target device must have launched the app at least once for its container to
exist. Editing that database directly also works — deleting a leftover stub
army is `sqlite3 "$DST/Documents/structor.sqlite" "delete from rosters where
id='…';"`, which beats tapping through a confirmation dialog.

**The status bar.** Apple's own screenshots read 9:41 with full bars:

```bash
xcrun simctl status_bar <udid> override --time "9:41" --dataNetwork wifi \
  --wifiMode active --wifiBars 3 --cellularMode active \
  --batteryState charged --batteryLevel 100
```

**The set, as shot.** Six, against a limit of ten, in the order that explains
the app:

| File | Screen | Why it is in the set |
| --- | --- | --- |
| `01-armies` | the army list | the weakest — one row on an empty screen. Keep it last or drop it. |
| `02-army` | the army page | 995 of 1000, six units, two detachments, the validation notes |
| `03-mission` | setup, step 2 | the mission each detachment would give you, with its scoring and its action — the decision the app exists to inform |
| `04-setup` | setup, the table | the deployment map drawn to scale, with its honest caption about bounding boxes |
| `05-turn` | the turn page | round, CP, the stratagems usable now, one expanded to its full printed text |
| `06-objectives` | objectives | both primaries, the score by round, and the disclaimer that these are community summaries |

No text overlays, no device frames, no marketing furniture — the same reason
the rest of the copy is plain.

## Taking the rest

[capture.sh](capture.sh) does the whole ritual — status bar, native
resolution, no scaling — and names the file by the size it actually got, so a
wrong-sized image cannot reach App Store Connect by accident:

```bash
store/screenshots/capture.sh 02-editor
```

Navigate the simulator to the screen, run it, repeat. `DEVICE="iPad Pro
13-inch (M5)"` switches devices for the iPad set. With no argument it prints
the five shots and what each should show.

## Status

**All six captured**, every one at 1320 x 2868 with the 9:41 status bar and a
real 995-point list.

Two things a second pass could improve, neither blocking: `06-objectives` shows
0–0 because the battle had just started, and `01-armies` is thin enough that
the set reads better without it. The iPad set is untouched — required only
while the app ships for iPad, which `TARGETED_DEVICE_FAMILY = "1,2"` says it
does.
