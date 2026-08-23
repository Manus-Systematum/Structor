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

**The set, as shot.** Seven for iPhone and four for iPad, against a limit of
ten each, in the order that explains the app:

| File | Screen | Why it is in the set |
| --- | --- | --- |
| `01-armies` | the army list | the weakest — one row on an empty screen. Keep it last or drop it. |
| `02-army` | the army page | 995 of 1000, six units, two detachments, the validation notes |
| `03-mission` | setup, step 2 | the mission each detachment would give you, with its scoring and its action — the decision the app exists to inform |
| `04-setup` | setup, the table | the deployment map drawn to scale, with its honest caption about bounding boxes |
| `05-turn` | the turn page | round 3, five CP, the stratagems usable now, one expanded to its printed text, and the VP steppers |
| `06-objectives` | objectives | 21–16 with the score by round, both primaries, and the disclaimer that these are community summaries |
| `07-rules` | the reference page | search, the army-wide rules, and the shared-rules matrix — the screen that most rewards a tablet |

The iPad set is `02`, `05`, `06` and `07`. `03` and `04` are not in it because
they belong to the setup wizard, which a battle in progress has already passed;
finishing the battle and setting up again would get them.

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

## The scored battle

`05-turn` and `06-objectives` show a game in its third round at 21–16, which no
amount of tapping would have produced quickly. The scores were written straight
into `rosters.battle_log_json` as `score` events in the app's own vocabulary —
`{"type":"score","side":"me","kind":"primary","round":1,"vp":6}` — so the app
reads them exactly as if they had been entered by hand. `battle_event.dart` is
the schema.

## Status

**All eleven files captured**, every one at its device's native size, from the
imported 995-point list.

Remaining, neither blocking: `01-armies` is thin enough that the iPhone set
reads better without it, and the iPad set has no setup-wizard shots.
