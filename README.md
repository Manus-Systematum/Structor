# Wh40k Companion

Cross-platform (iOS/Android) companion app for Warhammer 40,000 11th edition:
army builder, list import/sharing, and an in-game play mode.

Design lives in [DESIGN.md](DESIGN.md) — read that first. It is the authoritative
record of decisions, not the commit history.

## Layout

```
packages/wh40k_core/   pure Dart: source ingest, domain model, validation,
                       rules rendering. No Flutter dependency, so the same
                       code runs in the ETL, the app and (later) the server.
tools/                 data fetch and build scripts
data/40kdc/            vendored upstream snapshot (gitignored; refetchable)
```

## Getting started

Requires the Dart SDK (the app package, added later, will require Flutter).

```bash
tools/fetch-40kdc.sh                     # pull a 40kdc-data snapshot (tau-empire)
cd packages/wh40k_core && dart pub get
dart test
dart run bin/coverage.dart               # coverage + referential integrity
```

`coverage.dart` exits non-zero on any error-severity finding, so it can gate CI.

Fetch other factions by id:

```bash
tools/fetch-40kdc.sh necrons aeldari
```

## Releasing to TestFlight

```bash
cd packages/wh40k_app && flutter build ipa
```

**Increment the build number on every upload.** `pubspec.yaml` carries it after
the `+` — `0.1.0+2`. App Store Connect refuses a build number it has already
accepted, even when the version before it is unchanged.

The app's About screen carries the attribution the data licence requires, and
a test asserts it verbatim. Do not remove it.

## Licence

The code in this repository is **MIT** — see [LICENSE](LICENSE).

**The data is not, and MIT does not relicense it.** Everything the app knows
about the game comes from community projects that keep their own terms:

| Source | What it supplies | Terms |
| --- | --- | --- |
| [40kdc-data](https://github.com/wn-mitch/40kdc-data) | datasheets, weapons, abilities, missions, stratagem costs and phases | **CC BY 4.0** © Alpaca Software and the 40kdc community contributors; schemas CC0 |
| [Wahapedia](https://wahapedia.ru/wh40k11ed/) | the printed rules text of the stratagems | published data export; asks for "Powered by Wahapedia" |
| [stratagem-card-generator](https://github.com/pguetschow/warhammer-40k-stratagem-card-generator) | the eleven Core Stratagems, transcribed | MIT |
| [BSData/wh40k-11e](https://github.com/BSData/wh40k-11e) | datasheet and ability text | **no licence file**; maintainers gave permission in [issue 918](https://github.com/BSData/wh40k-11e/issues/918), which is not the same as a licence |
| [BSData/wh40k-11e-mfm](https://github.com/BSData/wh40k-11e-mfm) | Munitorum points, as a cross-check | MIT |
| [gdmissions.app](https://gdmissions.app) | the sentence printed on each mission card | publishes no licence, terms or notice |
| [Warhammer Community downloads](https://www.warhammer-community.com/en-gb/downloads/warhammer-40000/) | the Faction Packs, for the rules the community sources have not caught up with (§3.15) | Games Workshop's own free downloads, used as published; no licence is granted by them |

CC BY 4.0 obliges attribution, a link, and a statement that changes were made;
the About screen carries all three, and **a test asserts the phrase "Powered by
40kdc-data" verbatim**. If that test fails the app is out of compliance, and
the screen is what should change.

Warhammer 40,000 and all associated names, marks and imagery are © Games
Workshop Limited. This project is unofficial and unaffiliated. Some of what
the app shows is taken from Games Workshop's own freely published rules
downloads, which remain theirs.
