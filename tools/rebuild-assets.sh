#!/usr/bin/env bash
#
# Rebuilds every derived asset from data/40kdc and data-corrections.yaml.
#
# Three outputs, all committed, all easy to forget:
#
#   packages/wh40k_core/test/fixtures/tau_strike_force_2000.json  (from the export)
#   packages/wh40k_app/assets/reference_roster.json               (same file)
#   packages/wh40k_app/assets/reference_snapshot.json             (from the roster)
#   packages/wh40k_app/assets/bundles/                            (from the dataset)
#
# Forgetting the bundles is the dangerous one: the core tests read the dataset
# through a loader that applies corrections live, so they stay green while the
# app ships uncorrected data. `flutter test test/shipped_bundle_test.dart`
# catches it, and running this is how you fix it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core="$root/packages/wh40k_core"
app="$root/packages/wh40k_app"

if [ ! -d "$root/data/40kdc" ]; then
  echo "no snapshot at data/40kdc — run tools/fetch-40kdc.sh first" >&2
  exit 2
fi

cd "$core"

echo "==> importing the reference export"
dart run bin/import.dart test/fixtures/war_organ_export.txt \
  --out /tmp/reference-roster.json

# Keep the fixture's header comment, which says how to regenerate it.
python3 - "$core/test/fixtures/tau_strike_force_2000.json" <<'PY'
import collections, json, sys
target = sys.argv[1]
new = json.load(open('/tmp/reference-roster.json'),
                object_pairs_hook=collections.OrderedDict)
old = json.load(open(target), object_pairs_hook=collections.OrderedDict)
out = collections.OrderedDict()
if '_comment' in old:
    out['_comment'] = old['_comment']
out.update(new)
open(target, 'w').write(json.dumps(out, indent=2, ensure_ascii=False) + '\n')
PY

cp "$core/test/fixtures/tau_strike_force_2000.json" \
   "$app/assets/reference_roster.json"

echo "==> writing the reference snapshot"
dart run bin/roster.dart test/fixtures/tau_strike_force_2000.json \
  --snapshot "$app/assets/reference_snapshot.json"

echo "==> building the bundles"
dart run bin/bundle.dart --out "$app/assets/bundles"

echo
echo "done — now run both test suites before committing"
