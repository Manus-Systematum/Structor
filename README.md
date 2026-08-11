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

## Data and attribution

Rules data comes from [40kdc-data](https://github.com/wn-mitch/40kdc-data),
CC BY 4.0 © Alpaca Software and the 40kdc community contributors. Schemas are
CC0. Any public deployment must display "Powered by 40kdc-data" with a link to
<https://40kdc.alpacasoft.dev> — see DESIGN.md §3.0.

No Games Workshop rules text is bundled. Warhammer 40,000 is © Games Workshop
Limited; this project is unofficial and unaffiliated.
