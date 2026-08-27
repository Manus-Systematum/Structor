"""Faction Packs + the app's data -> data/updates/2026-08-26.json.

Scoped to the detachments the packs cover. A detachment nobody published a
pack for is left alone: the packs say nothing about it, and silence is not
evidence that its stratagems are wrong.

A pack detachment's records live in several faction files at once — every
Space Marine chapter carries its own copy of Armoured Speartip — so each file
naming that detachment gets its own operation.

Three kinds come out of the comparison:

  set     the record is right and its wording was never published
  remove  the app has a stratagem the released detachment does not
  add     the released detachment has one this faction's copy is missing

`add` never invents a record. Every one of them exists in some other
faction's copy of the same detachment, so the structural fields — phase,
timing, whose turn — are taken from that sibling and only the id, the text
and the cost come from the pack.
"""
import json, re, glob, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MERGED = f'{ROOT}/data/merged/core'
DATASLATE = 'pre-launch-provisional'

def key(s):
    return re.sub(r'[^a-z0-9]+', '', (s or '').lower())

def slug(s):
    return re.sub(r'-+', '-', re.sub(r'[^a-z0-9]+', '-', s.lower())).strip('-')

packs = json.load(open(f'{ROOT}/data/faction-packs.json'))
contents = json.load(open(f'{ROOT}/data/faction-pack-detachments.json'))

# Every detachment any pack covers, with the stratagems it publishes for it.
# Detachments listed in a contents page but carrying no stratagems are still
# registered: Sanctified Orators and Librarius Conclave have a rule and some
# enhancements and nothing else, checked against the rendered pages, and
# without them here the app's records for them would look uncovered.
covered = {}
for pack, listed in contents.items():
    for d in listed:
        covered.setdefault(key(d['name']), {'name': d['name'], 'strats': {}})
for pack, strats in packs.items():
    for s in strats:
        slot = covered.setdefault(key(s['detachment']),
                                  {'name': s['detachment'], 'strats': {}})
        slot['strats'][key(s['name'])] = s

# Every stratagem record in the app, so an `add` can be built from a sibling.
siblings = collections.defaultdict(list)
for path in glob.glob(f'{MERGED}/*/stratagems.json'):
    faction = os.path.basename(os.path.dirname(path))
    for r in json.load(open(path)):
        siblings[(key((r.get('detachment_id') or '').replace('-', ' ')),
                  key(r['name']))].append((faction, r))

ops = []
stats = collections.Counter()

for path in sorted(glob.glob(f'{MERGED}/*/stratagems.json')):
    faction = os.path.basename(os.path.dirname(path))
    records = json.load(open(path))
    by_det = collections.defaultdict(list)
    for r in records:
        by_det[key((r.get('detachment_id') or '').replace('-', ' '))].append(r)

    for det_key, app_records in sorted(by_det.items()):
        if det_key not in covered:
            continue
        pack_name = covered[det_key]['name']
        published = covered[det_key]['strats']
        seen = set()

        for r in sorted(app_records, key=lambda r: r['id']):
            k = key(r['name'])
            seen.add(k)
            found = published.get(k)
            if found is None:
                ops.append({
                    'faction': faction, 'file': 'stratagems', 'op': 'remove',
                    'id': r['id'],
                    'note': f'not in the {pack_name} pack',
                })
                stats['remove'] += 1
                continue

            values = {}
            if (r.get('text') or '').strip() != found['text']:
                values['text'] = found['text']
            if found['cp'] is not None and r.get('cp_cost') != found['cp']:
                values['cp_cost'] = found['cp']
            if values:
                ops.append({
                    'faction': faction, 'file': 'stratagems', 'op': 'set',
                    'id': r['id'], 'values': values,
                    'note': f'{pack_name} pack',
                })
                stats['set'] += 1

        # In the pack and not in this faction's copy of the detachment.
        detachment_id = next(
            (r.get('detachment_id') for r in app_records if r.get('detachment_id')),
            None)
        for k, found in sorted(published.items()):
            if k in seen:
                continue
            twin = next((r for f, r in siblings[(det_key, k)] if f != faction),
                        None)
            if twin is None:
                stats['add-skipped'] += 1
                continue
            new = {
                key_: twin[key_]
                for key_ in ('category', 'type', 'phases', 'player_turn',
                             'timing', 'target_restrictions', 'ability_id',
                             'game_version')
                if key_ in twin
            }
            new['name'] = found['name']
            new['detachment_id'] = detachment_id
            new['cp_cost'] = found['cp'] if found['cp'] is not None \
                else twin.get('cp_cost')
            new['text'] = found['text']
            ops.append({
                'faction': faction, 'file': 'stratagems', 'op': 'add',
                'id': f'{slug(found["name"])}-{detachment_id}',
                'values': new,
                'note': f'in the {pack_name} pack, missing from this faction',
            })
            stats['add'] += 1

patch = {
    'id': '2026-08-26',
    'name': 'August 2026 rules update',
    'appliesTo': DATASLATE,
    'source': 'Warhammer Community Faction Packs, 26 August 2026',
    'operations': ops,
}
out = f'{ROOT}/data/updates/2026-08-26.json'
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, 'w') as f:
    json.dump(patch, f, indent=1, ensure_ascii=False)
    f.write('\n')

print(f'{len(ops)} operations -> {out}')
for k, v in sorted(stats.items()):
    print(f'   {k:14} {v}')
print('   factions touched', len({o['faction'] for o in ops}))
