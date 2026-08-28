# App Store submission pack

Everything App Store Connect asks for, written out so it can be pasted rather
than composed at the keyboard. Prepared 2026-08-23 against `0.2.0+3`; the version is now `1.0.0+4`.

**§1 is decided: option 1, submit as built** (2026-08-24). The stratagem text
stays. Everything in this pack is written for that, so nothing below needs
changing before a submission — §11 remains as the recipe if the decision is
ever revisited.

The copy here is in the same plain register as the app and the site, decided in
`DESIGN.md` and the group's `CLAUDE.md`. The `product-voice` skill exempts
marketing copy, and that exemption is deliberately declined: this product's
claim is that it is free and unfunded, and an App Store page that suddenly
sells reads as the pitch the rest of the project says it is not making.

---

## 1. The intellectual-property question, stated plainly

Structor is an unofficial companion to a tabletop game whose rules, names and
imagery belong to Games Workshop. Two of Apple's guidelines bear on it:

- **5.2.1 (Generally)** — the app must not use third-party content without the
  rights to it.
- **5.2.5 (Apple Products / third-party marks)** — the app must not suggest
  endorsement it does not have.

**What the app actually ships, so the decision is made on facts:**

| Content | Origin | Standing |
| --- | --- | --- |
| Datasheets, weapons, abilities, missions, points | 40kdc-data | CC BY 4.0, attributed in-app |
| Ability and mission *descriptions* | 40kdc / gdmissions | community-written summaries, not GW's wording |
| **Stratagem rules text** | Wahapedia's published export | **this is Games Workshop's printed wording** |
| Datasheet and ability text | BSData | no licence file; maintainers' permission only |
| Mission card sentences | gdmissions.app | site publishes no terms at all |
| Names, keywords, faction and unit names | the game itself | GW trademarks, used descriptively |

The third row is the exposure. A CC BY licence on a community database does not
grant rights in Games Workshop's text, and the fact that Wahapedia publishes an
export does not either — Wahapedia is itself an unofficial site. **If this app
is rejected or taken down, that row is why.**

Three ways forward, in descending order of risk:

1. **Submit as built.** Many unofficial companions live on the store; some are
   removed after a rightsholder complaint. The app is free, which removes the
   commercial-use argument but not the copying one.
2. **Ship without the printed stratagem wording** — name, cost, phase and
   timing only, which is what the app did before §3.12, plus the community
   summaries. That leaves nothing of GW's text in the binary and makes the
   content-rights answer straightforwardly true. It is a real loss of function
   and reversible at any time.
3. **Ask Games Workshop.** Slow, probably unanswered, and not a blocker to
   either of the above.

**Decided 2026-08-24: option 1.** The app ships as built, with the stratagem
text. The review notes in §4 and the content-rights answer in §7 are written
for that and need no edit. §11 stays in the pack because the decision is
reversible and the recipe is worth keeping, not because it is pending.

---

## 2. Product page

### Name — 30 characters

```
Structor
```

**Not** "Structor: Warhammer 40K" or any variant carrying the trademark. Putting
another company's mark in the app name is one of the more reliably rejected
things on the store, and it is also the fact pattern that most invites a
rightsholder complaint. The cost is discovery, and it is real: nobody searching
for a 40k list builder will type "Structor". §2 keywords mitigate it as far as
is sensible.

### Subtitle — 30 characters

```
Army lists and play assistant
```

(29 characters.) Also trademark-free, for the same reason.

### Promotional text — 170 characters, editable without a new build

```
Thirty-five armies, list validation against the current detachment rules, and a play mode that keeps stratagems, victory points and statlines where you can reach them.
```

(167 characters.)

### Description — 4,000 characters

```
Structor is a companion for the eleventh edition of a tabletop miniatures wargame. It builds army lists under the detachment rules and runs beside a game: mission setup, the stratagems available in each phase, victory points, and the statlines you need mid-turn.

It works offline. Everything stays on the device.

BUILDING A LIST

- Thirty-five armies and the core rules are included in the app. No account, no download step.
- Detachment points, enhancement slots, unit caps and wargear limits are checked while you build, at the battle size you chose.
- A price that cannot be resolved is reported as a problem rather than counted as zero, so an incomplete list never reads as a cheap one.
- Paste a list exported as plain text from another builder. Names that do not match are listed rather than dropped silently.
- A saved list keeps a copy of the data it was built from, so a points update changes what you see next time you edit it, not what you already wrote down.

DURING A GAME

- Mission, deployment zones and terrain layout, drawn to scale from the published layout data.
- Each phase lists the stratagems usable in it, with the full text and the cost. Using one deducts the CP and records which unit used it, so the same unit cannot quietly use two.
- Primary and secondary scoring in the card's own wording, with the running total.
- Unit cards with per-model statlines, wounds and models remaining, and abilities attributed to the datasheet that grants them, so a leader's invulnerable save is not silently shared with the squad it joined.

WHAT IT DOES NOT DO

- Ability and mission descriptions are summaries written by the data projects, not the publisher's printed wording. They are enough to play from; for a rules dispute, use the card or the book.
- Some of the data is on a pre-launch provisional dataslate carried over from the previous edition. The app marks that where it applies rather than presenting it as current.
- Lists cannot yet be sent between devices.
- Nothing is collected. There are no accounts, no analytics and no tracking, and the app makes no network requests.

WHERE THE DATA COMES FROM

Structor holds no rules data of its own.

Powered by 40kdc-data — https://40kdc.alpacasoft.dev — licensed CC BY 4.0, © Alpaca Software and the 40kdc community contributors, schemas CC0. Changes were made: the data is repackaged into compressed bundles, corrected in a recorded set of places, and rendered by the app.

Powered by Wahapedia — https://wahapedia.ru/wh40k11ed/

Datasheet and ability text from BSData; mission card text from gdmissions.app; the Core Stratagems by way of the stratagem card generator by pguetschow. Where those sources have not caught up with a rules update, the wording comes from Games Workshop's own free Faction Pack downloads at warhammer-community.com.

Structor is free and open source. Its code is MIT licensed and lives at https://github.com/Manus-Systematum/Structor — the rules data keeps the terms named above.

Everything the app knows about the game was collected from the openly published sources named above, some of them Games Workshop's own free downloads. Warhammer 40,000, all associated names, marks and imagery, and any wording that matches Games Workshop's printed rules, remain © Games Workshop Limited. This app is unofficial and is neither endorsed by nor affiliated with Games Workshop.
```

(3,373 characters, against a 4,000 limit.)

### Keywords — 100 characters, comma-separated, no spaces after commas

Two sets. **Pick one deliberately**, because this is the same trade as the app
name in a field almost nobody reads.

Conservative — no third-party marks:

```
wargame,tabletop,army,list,builder,roster,miniatures,stratagem,mission,battle,points,detachment
```

(95 characters.) Discoverable — includes the terms people actually search:

```
warhammer,40k,wargame,tabletop,army,builder,roster,list,miniatures,stratagem,mission,detachment
```

(95 characters.) Apple has historically been more relaxed about a trademark in
keywords than in the name, and a rightsholder complaint does not care about the
distinction. The first set is the one consistent with the naming decision above;
choosing the second is choosing a different risk posture, not a small tweak.

### URLs

| Field | Value |
| --- | --- |
| Marketing URL | `https://structor.systematum.net` |
| Support URL | `https://systematum.net/#support` |
| Privacy Policy URL | `https://structor.systematum.net/privacy.html` |

All three are live as of 2026-08-23. The privacy page was written for this
submission and answers Apple's questions directly.

### Categories

| Field | Value | Why |
| --- | --- | --- |
| Primary | **Reference** | it is a rules reference with an editor attached |
| Secondary | **Utilities** | the builder half |

Not Games: it plays nothing.

### Copyright

```
2026 manus systematum
```

Note that *manus systematum* is a distribution name, not a legal entity. If App
Store Connect's account holder is a person, that name is what appears elsewhere
on the listing regardless of this field.

---

## 3. Age rating

Answer the questionnaire honestly; the expected result is **4+**.

| Question | Answer |
| --- | --- |
| Violence — cartoon, fantasy, realistic, prolonged graphic | **None.** The app has no imagery and no depiction. Words like "destroyed" appear in rules text about model removal. |
| Sexual content, nudity, profanity, crude humour | None |
| Alcohol, tobacco, drugs | None |
| Horror / fear themes | None |
| Gambling, contests | None |
| Medical / treatment information | None |
| Unrestricted web access | **No** — the app has no browser and makes no requests |
| User-generated content | **No** — nothing is shared between users |
| Messaging or chat | No |
| Location sharing | No |

If you would rather be conservative, 9+ costs nothing and forecloses an
argument. 4+ is defensible on the content as shipped.

---

## 4. App Review information

**Sign-in required:** No. The app opens straight into an empty army list with
no account of any kind.

**Contact:** the Apple ID account holder's own details.

**Notes to the reviewer** — the full text is in
[review-notes.txt](review-notes.txt), kept separate so it can be pasted
without markdown. It covers what the app is, that no sign-in is needed, where
the data comes from and under what licences, and the unofficial/unaffiliated
statement. **If you take option 2 in §1, the paragraph about stratagem text is
the one to change.**

---

## 5. App Privacy

Every category: **Data Not Collected**.

This is checkable rather than asserted. The app's whole dependency list is
`drift` and `sqlite3_flutter_libs` (a local database), `path` and
`path_provider` (file locations), and `package_info_plus` (its own version
string). There is no analytics SDK, no advertising SDK, no crash reporter, and
no HTTP client is ever constructed — `main.dart` builds `DatasetRepository`
without a remote source, so the download path that exists in the code is inert.

Answer **No** to "Does this app use the Advertising Identifier (IDFA)?".

---

## 6. Export compliance

`ITSAppUsesNonExemptEncryption = false` is already in `Info.plist`, so App Store
Connect stops asking per build. The declaration is accurate: HTTPS would use the
operating system's own TLS, the database is plain SQLite with no SQLCipher, and
the only cryptographic primitive in the code is a SHA-256 digest used to verify
a bundle — a hash, not encryption.

---

## 7. Content rights

App Store Connect asks: *does your app contain, display, or access third-party
content?* The answer is **Yes**, and the following checkbox asserts you have the
rights or permission to use it. §1 is the discussion of what that assertion is
worth here. Do not tick it without having read that section.

---

## 8. Screenshots

Required: one set at **6.9-inch** (1320 × 2868 or 1290 × 2796). Apple scales
that set down for smaller iPhones, so it is the only mandatory size. The app
also builds for iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), and **an iPad set at
13-inch (2064 × 2752) is required if iPad remains enabled** — dropping iPad
support is the alternative and is a one-line change.

Between 3 and 10 per set. What to show, in the order that explains the app:

1. **The army list** — a real 2,000-point list, several units, points totalling.
2. **The editor** — a unit open, wargear options and the validation state.
3. **The turn page** — a phase with its stratagems, one expanded, CP visible.
4. **Setup** — the mission with the deployment map drawn.
5. **Objectives** — primary and secondary scoring with a running total.

**These do not exist yet.** The simulator's stored data is a one-unit stub, and
a screenshot of an empty app describes the app worse than a sentence does. Get
a real list in first — pasting the reference 2,000-point list into the import
screen is the quickest route.

No text overlays, no device frames, no marketing furniture: the same reason the
rest of the copy is plain.

---

## 9. Build and upload

**Check the icons first.** An upload on 2026-08-23 was rejected with four
"Missing required icon file" errors — 120, 152, 167 and the 1024 marketing
icon — for a project whose asset catalog contains all four and whose icons are
opaque RGB with no alpha. The catalog was not the problem; the archive was.
A stale `DerivedData` is the usual cause, and the only place it shows is the
upload.

```bash
store/verify-icons.sh                      # the last release build
store/verify-icons.sh path/to/Structor.ipa # or the archive you are about to send
```

It reads the built bundle rather than the catalog — `CFBundleIconName` in
`Info.plist` and the compiled `Assets.car` — because that is what App Store
Connect reads. If it fails, clear the cache and rebuild:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
cd packages/wh40k_app && flutter clean && flutter build ipa
```


```bash
cd packages/wh40k_app && flutter build ipa
```

**Increment the build number on every upload.** `pubspec.yaml` carries it after
the `+`. App Store Connect refuses a build number it has already accepted, even
when the version before it is unchanged. `0.2.0+3` is uploaded; the next is
`1.0.0+4`, which is what `pubspec.yaml` now reads.

Then Xcode → Organizer → Distribute App, or `xcrun altool`/Transporter with the
`.ipa` from `build/ios/ipa/`.

---

## 10. What only you can do

- Accept any pending agreements in App Store Connect (a build cannot be
  submitted while one is outstanding).
- Reserve the app name — it is first-come, and "Structor" may be taken.
- Set up the app record: bundle ID `dev.structor.app`, primary language,
  availability, and price (free).
- Answer the age-rating, privacy and content-rights forms — §§3, 5 and 7 are
  the answers, but they are declarations under your account.
- Upload the build and attach the screenshots.

---

## 11. If you take option 2 from §1

Removing the printed stratagem wording is a data-pipeline change, not an app
change:

- `bin/merge.dart` — `_applyStratagemText` is the pass that folds Wahapedia's
  export in. Skipping it leaves every stratagem with name, cost, phase and
  timing, which is what shipped before §3.12.
- `data/stratagem-text/` and the Wahapedia entry in the About screen and README
  would go with it, along with `stratagem_book_test`'s coverage floor.
- The app degrades rather than breaks: a stratagem with no text renders as
  name, cost and phase, which is what every one of the 116 still-missing ones
  does today. Nothing in the UI needs changing. What *would* need saying is
  that the wording is absent by choice — no screen says that at present.

Budget an hour, plus a rebuild of the bundles and both suites.

---

## 12. Before submitting

- [x] §1 decided — option 1, submit as built (2026-08-24); review notes match
- [x] **Build number** — `1.0.0+4` (2026-08-28). `+3` was the number the
      earlier TestFlight build used, so the next upload had to move past it
      whatever the version did.
- [x] Screenshots — eleven, 6.9-inch and iPad-13, against the current build
- [x] Both suites green (482 core, 189 app) and the shipped-bundle guard passes
- [x] The three URLs resolve — checked 2026-08-24
- [x] About screen shows "Powered by 40kdc-data" — `about_test` asserts it, and
      a failure there means the app is out of licence compliance
