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

**What to shoot,** in the order that explains the app:

| File | Screen | State it needs |
| --- | --- | --- |
| `01-armies` | the army list | the imported list, and nothing else in the list |
| `02-editor` | Edit army | scrolled to show 995/1000, the detachments and the first units |
| `03-turn` | the turn page | a phase with its stratagems, one expanded, CP visible |
| `04-setup` | setup | the mission with the deployment map drawn |
| `05-objectives` | objectives | primary and secondary scoring with a running total |

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

`01-armies-6.9.png` is captured, at 1320 x 2868 with the imported list. It is
also the weakest of the five — one row on an otherwise empty screen. **Lead
with `02-editor`** once it exists.

The other four need the simulator driven by hand or by an agent with device
access. The 995-point list is already on the iPhone 17 Pro Max, so it is five
screens of navigation, not another import.
