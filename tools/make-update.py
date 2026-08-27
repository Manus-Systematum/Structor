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

PACK_TO_FACTION = {'space-marines': 'adeptus-astartes'}


# --------------------------------------------------------------- rules updates

"""The Rules Updates sections, mapped onto records.

Enhancements and detachments carry no wording of their own — theirs lives in
the `abilities` file, reached by `ability_id` and `detachment_rule_id`. So
almost every correction here ends up setting one ability's `description`, and
the work is deciding *which*.

Only whole replacements are taken. `Change 9" to 8".` and `Add 'FRAME'.` edit
a phrase inside prose the app stores as one string, and applying them would
mean rewriting rules text by pattern — which is the thing §0 forbids. They are
counted and reported instead.
"""

import gzip

BUNDLES = f'{ROOT}/packages/wh40k_app/assets/bundles'

# A subject naming a part of a rule rather than the whole of it: the
# correction replaces that part, and the app has no such part to replace.
SECTION = re.compile(r',\s*(when|target|effect|restrictions|keywords|abilities)'
                     r'\s+section\b', re.I)

SUBJECT = re.compile(r'^(?:(?P<owner>.*?),\s*)?(?P<name>.+?)\s+'
                     r'(?P<kind>Enhancement|Stratagem|Detachment [Rr]ule|'
                     r'[Aa]bility|[Aa]bilities)$')


def bundled():
    """Every faction bundle's files, by faction id."""
    out = {}
    for path in sorted(glob.glob(f'{BUNDLES}/*.json.gz')):
        with gzip.open(path) as f:
            bundle = json.load(f)
        if 'files' in bundle:
            out[bundle['id']] = bundle['files']
    return out


def quoted(text):
    """The replacement wording, in the shape the app's own text arrives in.

    The quotation marks around it come off, and the packs' `▪` becomes a
    newline and a dash: 123 of the T'au abilities already bullet that way and
    none of them use `▪`, so leaving it would render one rule unlike every
    other rule beside it.
    """
    body = text.strip()
    for opener, closer in (('‘', '’'), ("'", "'"), ('"', '"')):
        if body.startswith(opener):
            body = body[1:]
            if body.endswith(closer):
                body = body[:-1]
            break
    body = re.sub(r'\s*[▪●•]\s*', '\n- ', body)
    # A nested bullet is a sub-point of the one above it.
    body = re.sub(r'\s*[◦□]\s*', '\n  - ', body)
    return re.sub(r'\n{3,}', '\n\n', body).strip()


def rules_update_ops(packs_to_factions):
    updates_at = f'{ROOT}/data/faction-pack-updates.json'
    if not os.path.exists(updates_at):
        return [], collections.Counter()

    updates = json.load(open(updates_at))
    files = bundled()
    ops, skipped = [], collections.Counter()

    for pack, corrections in sorted(updates.items()):
        faction = packs_to_factions.get(pack, pack)
        bundle = files.get(faction)
        if bundle is None:
            skipped['no bundle for this pack'] += len(corrections)
            continue

        detachments = {key(d['name']): d for d in bundle.get('detachments', [])}
        enhancements = collections.defaultdict(dict)
        for e in bundle.get('enhancements', []):
            enhancements[e.get('detachment_id')][key(e['name'])] = e
        stratagems = collections.defaultdict(dict)
        for s in bundle.get('stratagems', []):
            stratagems[s.get('detachment_id')][key(s['name'])] = s
        abilities = collections.defaultdict(list)
        for a in bundle.get('abilities', []):
            abilities[key(a['name'])].append(a)
        units = {u['id']: u for u in bundle.get('units', [])}

        for correction in corrections:
            category = (correction['category'] or '').strip()
            subject = correction['subject'].strip()
            directive = correction['directive'].rstrip()

            # `Change to:` opens a replacement; anything else edits a phrase.
            if not directive.endswith(':'):
                skipped['edits a phrase, not a whole rule'] += 1
                continue
            if SECTION.search(subject):
                skipped['replaces one section of a rule'] += 1
                continue

            parsed = SUBJECT.match(subject)
            if parsed:
                kind = parsed.group('kind').lower()
                name = key(parsed.group('name'))
                owner = parsed.group('owner')
            else:
                # An army rule is named without saying what it is — `For the
                # Greater Good`, not `For the Greater Good Ability` — and so
                # is a datasheet's rule where the pack shortens it. The name
                # either matches an ability or it does not, and the lookup
                # below is what decides.
                kind = 'ability'
                owner, _, tail = subject.rpartition(',')
                name = key(tail if owner else subject)
                owner = owner.strip() or None
            text = quoted(correction['text'])
            note = f'{pack} pack rules update'

            def ability_op(ability_id):
                return {
                    'faction': faction, 'file': 'abilities', 'op': 'set',
                    'id': ability_id, 'key': 'ability_id',
                    'values': {'description': text}, 'note': note,
                }

            # The heading above a subject can be stale — a datasheet ability is
            # printed under whichever detachment heading came last — so the
            # subject's own shape is tried first and the heading only scopes
            # the things that need scoping.
            if kind in ('ability', 'abilities'):
                found = abilities.get(name, [])
                if len(found) > 1 and owner:
                    wanted = key(owner)
                    found = [a for a in found if any(
                        key(units.get(u, {}).get('name', '')) == wanted
                        for u in a.get('unit_ids', []))] or found
                if len(found) == 1:
                    ops.append(ability_op(found[0]['ability_id']))
                else:
                    skipped['no ability of that name' if not found
                            else 'that ability name is not unique'] += 1
                continue

            detachment = detachments.get(
                key(category[:-len('DETACHMENT')].strip())
                if category.endswith('DETACHMENT') else '')
            if detachment is None:
                skipped['no detachment heading to scope it'] += 1
                continue

            if kind == 'enhancement':
                found = enhancements[detachment['id']].get(name)
                if found and found.get('ability_id'):
                    ops.append(ability_op(found['ability_id']))
                else:
                    skipped['no enhancement of that name'] += 1
            elif kind == 'stratagem':
                found = stratagems[detachment['id']].get(name)
                if found:
                    ops.append({
                        'faction': faction, 'file': 'stratagems', 'op': 'set',
                        'id': found['id'], 'values': {'text': text},
                        'note': note,
                    })
                else:
                    skipped['no stratagem of that name'] += 1
            else:
                rule = detachment.get('detachment_rule_id')
                if rule:
                    ops.append(ability_op(rule))
                else:
                    skipped['detachment has no rule to correct'] += 1

    return ops, skipped


if __name__ == '__main__':
    rules_ops, skipped = rules_update_ops(PACK_TO_FACTION)
    ops.extend(rules_ops)

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
    print('\nfrom the detachment pages:')
    for k, v in sorted(stats.items()):
        print(f'   {k:16} {v}')
    print(f'\nfrom the rules updates: {len(rules_ops)} applied')
    for k, v in skipped.most_common():
        print(f'   not applied  {k:38} {v}')
    print(f'\nfactions touched {len({o["faction"] for o in ops})}')
