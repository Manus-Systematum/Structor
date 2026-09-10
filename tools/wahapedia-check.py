#!/usr/bin/env python3
"""Check the shipped dataset against Wahapedia, judged by Games Workshop.

**Wahapedia on its own is noise.** Compared bracket by bracket it disagrees
with our data on 599 of 1,943 unit prices — 30% — and it is right about 17 of
them. Reporting all 599 would bury the seventeen. So this does what §3.5 does
with the Munitorum mirror: it treats a second source as a way of *finding*
candidates and a third as the way of *judging* them.

    ours != Wahapedia            → a candidate, nothing more
    ... and GW's page backs Wahapedia  → we are wrong. Reported.
    ... and GW's page backs us         → Wahapedia is stale. Silent.
    ... and GW says a third thing      → all three differ. Reported separately.
    ... and GW has no row for it       → unadjudicated. Counted, not reported.

The judge is `data/mfm-points.json`, scraped from mfm.warhammer-community.com
by tools/fetch-mfm-points.py — Games Workshop's own published points.

**Terms.** Wahapedia's export page states them: "The export data can be used to
research game mechanics and develop related interfaces. When publishing your
work, mentioning Wahapedia is highly recommended." The app's About screen names
it. robots.txt disallows `/wh40k11ed_/`, a staging path; the export at
`/wh40k11ed/` is not disallowed. Files are cached under data/wahapedia/ and
only refetched when older than a day, or with --refresh.

Usage:
    tools/wahapedia-check.py [faction ...] [--refresh] [--json out.json]
"""
import argparse
import collections
import csv
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
CACHE = os.path.join(ROOT, 'data', 'wahapedia')
MERGED = os.path.join(ROOT, 'data', 'merged', 'core')
MFM = os.path.join(ROOT, 'data', 'mfm-points.json')

BASE = 'https://wahapedia.ru/wh40k11ed'
FILES = ['Factions', 'Datasheets', 'Datasheets_models_cost', 'Datasheets_models']
MAX_AGE = 24 * 60 * 60

# Wahapedia files one Space Marine faction; we file a chapter each, and it
# calls two factions by another name than the dataset does.
ALIASES = {'adeptus astartes': 'SM', 'agents of the imperium': 'AoI'}


def fold(text):
    """Names compared the way a person would: case, punctuation and the
    Atlantic spelling of *armour* all set aside."""
    text = (text or '').lower().replace('’', "'").replace('armour', 'armor')
    return re.sub(r'[^a-z0-9]+', ' ', text).strip()


def fetch(refresh=False):
    os.makedirs(CACHE, exist_ok=True)
    for name in FILES:
        path = os.path.join(CACHE, f'{name}.csv')
        fresh = os.path.exists(path) and time.time() - os.path.getmtime(path) < MAX_AGE
        if fresh and not refresh:
            continue
        request = urllib.request.Request(
            f'{BASE}/{name}.csv',
            headers={'User-Agent': 'structor-datacheck/1.0 '
                                   '(github.com/Manus-Systematum/Structor)'},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
        with open(path, 'wb') as out:
            out.write(body)
        print(f'  fetched {name}.csv ({len(body):,} bytes)', file=sys.stderr)


def rows(name):
    path = os.path.join(CACHE, f'{name}.csv')
    with open(path, encoding='utf-8-sig') as handle:
        return list(csv.DictReader(handle, delimiter='|'))


def scope_of(label):
    """The copy this price applies to, from a scope heading.

    All three sources write the same idea three ways — `YOUR 1ST TO 3RD UNITS
    COST`, `unit_count_min: 4`, `YOUR 4TH + UNIT COSTS` — and a price compared
    across scopes is not a disagreement, it is a different question. Boyz are
    75 points for the first three units and 85 after that; reading the second
    against another source's first makes every scoped datasheet look wrong.
    """
    match = re.search(r'(\d+)(?:st|nd|rd|th)', label or '', re.I)
    return int(match.group(1)) if match else 1


def load_wahapedia():
    factions = {r['id']: r['name'] for r in rows('Factions') if r.get('id')}
    by_name = {fold(v): k for k, v in factions.items()}
    by_name.update(ALIASES)

    # Scopes are header rows with an empty cost, and the model rows under them
    # belong to whichever came last.
    costs = collections.defaultdict(dict)
    scope = collections.defaultdict(lambda: 1)
    for row in sorted(rows('Datasheets_models_cost'),
                      key=lambda r: (r.get('datasheet_id') or '',
                                     int(r.get('line') or 0))):
        sheet = row.get('datasheet_id')
        description = row.get('description') or ''
        cost = (row.get('cost') or '').strip()
        if not cost:
            scope[sheet] = scope_of(description)
            continue
        match = re.match(r'\s*(\d+)\s*model', description, re.I)
        if match and cost.isdigit():
            costs[sheet][(int(match.group(1)), scope[sheet])] = int(cost)

    prices = {}
    for row in rows('Datasheets'):
        if row.get('id') and costs.get(row['id']):
            prices[(row['faction_id'], fold(row['name']))] = costs[row['id']]
    return by_name, prices


def load_gw():
    """Games Workshop's own points, by (faction, folded name) → models → cost."""
    if not os.path.exists(MFM):
        return {}
    out = {}
    for faction, data in json.load(open(MFM)).items():
        for unit in data.get('units', []):
            tiers = {}
            for entry in unit.get('costs', []):
                copy = scope_of(entry.get('scope'))
                for tier in entry.get('tiers', []):
                    match = re.match(r'\s*(\d+)\s*model', tier.get('of', ''), re.I)
                    if match:
                        tiers[(int(match.group(1)), copy)] = tier['cost']
            if tiers:
                out[(faction, fold(unit['name']))] = tiers
    return out


def our_factions(by_name):
    out = {}
    for entry in sorted(os.listdir(MERGED)):
        path = os.path.join(MERGED, entry, 'factions.json')
        if not os.path.isfile(path):
            continue
        for record in json.load(open(path)):
            if record.get('id') != entry:
                continue
            waha = by_name.get(fold(record.get('name')))
            if not waha and record.get('parent_faction_id') == 'adeptus-astartes':
                waha = 'SM'
            out[entry] = waha
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('factions', nargs='*')
    parser.add_argument('--refresh', action='store_true')
    parser.add_argument('--json')
    args = parser.parse_args()

    fetch(refresh=args.refresh)
    by_name, waha = load_wahapedia()
    gw = load_gw()
    if not gw:
        print('data/mfm-points.json is missing — run tools/fetch-mfm-points.py.\n'
              'Without it every difference is a candidate and none can be judged.',
              file=sys.stderr)
        return 2
    mapping = our_factions(by_name)

    wrong, three_way = [], []
    counts = collections.Counter()
    seen = set()
    wanted = set(args.factions)
    for faction, waha_id in sorted(mapping.items()):
        if wanted and faction not in wanted:
            continue
        if not waha_id:
            counts['faction not in Wahapedia'] += 1
            continue
        path = os.path.join(MERGED, faction, 'units.json')
        if not os.path.isfile(path):
            continue
        for unit in json.load(open(path)):
            key = (waha_id, fold(unit['name']))
            if key in seen:
                continue
            seen.add(key)
            theirs = waha.get(key)
            if theirs is None:
                counts['datasheet not in Wahapedia'] += 1
                continue
            judge = gw.get((faction, fold(unit['name'])))
            for bracket in unit.get('points') or []:
                models, cost = bracket.get('models'), bracket.get('cost')
                if models is None or cost is None:
                    continue
                where = (models, bracket.get('unit_count_min') or 1)
                if where not in theirs:
                    counts['no matching scope'] += 1
                    continue
                counts['compared'] += 1
                if theirs[where] == cost:
                    continue
                counts['differs from Wahapedia'] += 1
                label = unit['name'] if where[1] == 1 else \
                    f"{unit['name']} (copy {where[1]}+)"
                if not judge or where not in judge:
                    counts['no GW row to judge'] += 1
                elif judge[where] == cost:
                    counts['Wahapedia stale'] += 1
                elif judge[where] == theirs[where]:
                    wrong.append((faction, label, models, cost, theirs[where]))
                else:
                    three_way.append((faction, label, models, cost,
                                      theirs[where], judge[where]))

    print(f'compared {counts["compared"]:,} price brackets against Wahapedia\n')
    if wrong:
        print(f'{len(wrong)} where Games Workshop backs Wahapedia against us:')
        for faction, name, models, ours, theirs in wrong:
            print(f'   {faction:20} {name[:30]:32} {models:>3}m  '
                  f'ours {ours:>4}  should be {theirs:>4}')
        print()
    if three_way:
        print(f'{len(three_way)} where all three sources differ:')
        for faction, name, models, ours, theirs, judged in three_way:
            print(f'   {faction:20} {name[:30]:32} {models:>3}m  '
                  f'ours {ours:>4}  waha {theirs:>4}  GW {judged:>4}')
        print()
    for key in ('differs from Wahapedia', 'Wahapedia stale', 'no GW row to judge',
                'datasheet not in Wahapedia'):
        if counts[key]:
            print(f'   {counts[key]:5}  {key}')

    if args.json:
        with open(args.json, 'w') as out:
            json.dump({
                'counts': dict(counts),
                'wrong': [dict(zip(
                    ('faction', 'unit', 'models', 'ours', 'shouldBe'), row))
                    for row in wrong],
                'threeWay': [dict(zip(
                    ('faction', 'unit', 'models', 'ours', 'wahapedia', 'gw'), row))
                    for row in three_way],
            }, out, indent=1)
        print(f'\nwritten to {args.json}')

    # Non-zero only for the ones a person has to act on.
    return 1 if wrong else 0


if __name__ == '__main__':
    sys.exit(main())
