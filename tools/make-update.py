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
PATCH_ID = '2026-08-26'

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
# A subject naming a part of a rule rather than the whole of it. The app
# holds the rule as one string with `**WHEN:**`-style headings in it, so the
# named part can be replaced inside it.
SECTION = re.compile(r'[,\-–—]\s*(?P<part>[\w ]+?)\s+sections?\s*$', re.I)


def sections_named(subject):
    """`(parts, subject-without-them)`, or `([], subject)`.

    The separator is a comma in most packs and an en dash in others, and the
    packs write `Target and Effect Sections` when one correction replaces
    two — so this returns a list, not a part.
    """
    found = SECTION.search(subject)
    if not found:
        # `Taking Cover Section` is a section and nothing else: the rule it
        # belongs to is the one the heading above it names.
        whole = re.match(r'^(?P<part>[\w\' ]+?)\s+sections?\s*$', subject, re.I)
        if whole:
            return [whole.group('part').strip().lower()], ''
        return [], subject
    phrase = found.group('part').lower()
    parts = [p.strip().split()[-1] for p in re.split(r'\band\b', phrase)
             if p.strip()]
    return parts, subject[:found.start()].strip()

# The sections a stratagem's own text is divided into. `Transport`, `Leader`
# and the rest name parts of a datasheet, which is a different shape.
TEXT_SECTIONS = ('when', 'target', 'effect', 'restrictions')

SUBJECT = re.compile(r'^(?:(?P<owner>.*?),\s*)?(?P<name>.+?)\s+'
                     r'(?P<kind>Enhancement|Stratagem|Detachment [Rr]ule|'
                     r'[Aa]bility|[Aa]bilities)$')

# `Change 9" to 8".` — a measurement swapped for another, and nothing else.
MEASURE = re.compile(r'^Change\s+(?P<from>\d+(?:\.\d+)?["”″])\s+to\s+'
                     r'(?P<to>\d+(?:\.\d+)?["”″])\.?$', re.I)

# `Add 'FRAME'.` and `Remove 'Leader', add 'Support'.`
ADD_ONE = re.compile(
    r"^Add\s+(?:the\s+)?['‘\"](?P<what>[^'’\"]+)['’\"](?:\s+keyword)?\.?$", re.I)
SWAP = re.compile(r"^Remove\s+['‘\"](?P<out>[^'’\"]+)['’\"],\s*add\s+"
                  r"['‘\"](?P<in>[^'’\"]+)['’\"]\.?$", re.I)


STATLINE = re.compile(
    r"^Change\s+(?P<fields>[A-Za-z ]{1,26}?)"
    r"(?:\s+characteristics?)?\s+to\s+['‘\"]?(?P<value>[^'’\".]+)['’\"]?\.?$",
    re.I)

# What the packs call a characteristic, and what the profile record calls it.
STAT_FIELDS = {
    'm': 'M', 'move': 'M', 't': 'T', 'toughness': 'T', 'sv': 'Sv',
    'save': 'Sv', 'w': 'W', 'wounds': 'W', 'ld': 'Ld', 'leadership': 'Ld',
    'oc': 'OC',
}

# A weapon's profile keys the same characteristics under different names.
WEAPON_FIELDS = {
    'a': 'A', 'attacks': 'A', 'bs': 'BS', 'ws': 'WS', 's': 'S',
    'strength': 'S', 'ap': 'AP', 'd': 'D', 'damage': 'D',
}


def replace_named_block(text, heading, replacement):
    """A shouted sub-heading's block inside a rule, swapped.

    A detachment rule is one description with its parts shouted inside it —
    `BOMBARDMENT ... TAKING COVER ...` — and a correction can name one of
    them. The block runs from the heading to the next shouted heading, or to
    the end. Returns None when the heading is not there, so a correction that
    cannot find its target is reported rather than guessed at.
    """
    if not text:
        return None
    upper = text.upper()
    at = upper.find(heading.upper())
    if at < 0:
        return None
    after = at + len(heading)
    nxt = re.search(r'\n\s*(?:\*\*)?[A-Z][A-Z \'’\-]{4,}(?:\*\*)?',
                    text[after:])
    end = after + (nxt.start() if nxt else len(text) - after)
    return text[:after] + '\n' + replacement.strip() + text[end:]


def replace_section(text, part, replacement):
    """A rule's named section swapped, leaving the rest of it alone.

    Returns None when the section is not there to replace: a correction that
    cannot find its target is reported, never guessed at.
    """
    pattern = re.compile(r'(\*\*' + part.upper() + r':\*\*)(.*?)'
                         r'(?=\n\n\*\*[A-Z]+:\*\*|$)', re.S)
    if not pattern.search(text or ''):
        return None
    body = replacement.strip()
    # The pack quotes the replacement with its own heading sometimes.
    body = re.sub(r'^\*\*' + part.upper() + r':\*\*\s*', '', body, flags=re.I)
    return pattern.sub(lambda m: f'{m.group(1)} {body}', text, count=1)


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
        if not body.startswith(opener):
            continue
        body = body[1:]
        # Cut at a closing quote only where what follows it is plainly the
        # next entry — a heading, or nothing. The closer and the apostrophe
        # are the same character, so cutting at the last one truncated
        # `The first time this unit’s FABIUS BILE model is destroyed...` to
        # four words.
        for at in range(len(body) - 1, 0, -1):
            if body[at] != closer:
                continue
            rest = body[at + 1:].strip()
            if not rest or re.match(r'^[A-Z][A-Z \'’\-]{3,}', rest):
                body = body[:at]
                break
        break
    body = re.sub(r'\s*[▪●•]\s*', '\n- ', body)
    # A nested bullet is a sub-point of the one above it.
    body = re.sub(r'\s*[◦□]\s*', '\n  - ', body)

    # A stratagem's sections are printed as running text here — `WHEN: ...
    # TARGET: ...` — where the app holds them as `**WHEN:**` paragraphs. Ten
    # of the replacements flattened a stratagem into one unheaded blob before
    # this, which is worse than the wording being a version out of date.
    if not re.search(r'\*\*(WHEN|TARGET|EFFECT|RESTRICTIONS):\*\*', body):
        body = re.sub(r'\b(WHEN|TARGET|EFFECT|RESTRICTIONS):\s*',
                      lambda m: f'\n\n**{m.group(1)}:** ', body)
    # A bullet with nothing after it is the start of the next entry, not part
    # of this one.
    body = re.sub(r'\n\s*-\s*$', '', body)
    return re.sub(r'\n{3,}', '\n\n', body).strip()


# A replacement that still ends in a run of shouted words has the next entry's
# heading on it. One of the 174 does, and it is dropped rather than shipped:
# the app keeping wording that is a version out of date beats it showing
# wording with somebody else's heading welded to the end.
LEAKED = re.compile(r'\b[A-Z]{3,}(?: [A-Z]{3,}){2,}\s*\S*$')


def rules_update_ops(packs_to_factions):
    """Every correction that can be placed on a record, as operations.

    Four shapes, and each is refused rather than guessed at when its target
    is not found:

      whole      `Change to:` a rule, replacing its wording outright
      section    `Change to:` one named part of a rule, replaced inside it
      measure    `Change 9" to 8".` — one distance, if it occurs exactly once
      keywords   `Add 'FRAME'.` and `Remove 'Leader', add 'Support'.`

    The measurement one is the only place this rewrites rules text by
    pattern, and it is bounded: Games Workshop specify both the old value and
    the new, and the substitution is refused unless the old appears exactly
    once in the record. Two occurrences means the correction is ambiguous and
    the app should keep the wording it has.
    """
    updates_at = f'{ROOT}/data/faction-pack-updates.json'
    if not os.path.exists(updates_at):
        return [], collections.Counter()

    updates = json.load(open(updates_at))
    files = bundled()
    ops, skipped, refused = [], collections.Counter(), []

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
        for st in bundle.get('stratagems', []):
            stratagems[st.get('detachment_id')][key(st['name'])] = st
        abilities = collections.defaultdict(list)
        for a in bundle.get('abilities', []):
            abilities[key(a['name'])].append(a)
        by_ability_id = {a['ability_id']: a for a in bundle.get('abilities', [])}
        units = {u['id']: u for u in bundle.get('units', [])}
        units_by_name = {key(u['name']): u for u in units.values()}

        def target_for(subject, category):
            """The record a subject names: `(file, id, key, field, record)`."""
            parsed = SUBJECT.match(subject)
            if parsed:
                kind = parsed.group('kind').lower()
                name = key(parsed.group('name'))
                owner = parsed.group('owner')
            else:
                # An army rule is named without saying what it is — `For the
                # Greater Good`, not `For the Greater Good Ability`.
                kind = 'ability'
                owner, _, tail = subject.rpartition(',')
                name = key(tail if owner else subject)
                owner = owner.strip() or None

            if kind in ('ability', 'abilities'):
                found = abilities.get(name, [])
                if len(found) > 1 and owner:
                    wanted = key(owner)
                    narrowed = [a for a in found if any(
                        key(units.get(u, {}).get('name', '')) == wanted
                        for u in a.get('unit_ids', []))]
                    found = narrowed or found
                if len(found) != 1:
                    return None, ('no ability of that name' if not found
                                  else 'that ability name is not unique')
                a = found[0]
                return ('abilities', a['ability_id'], 'ability_id',
                        'description', a), None

            detachment = detachments.get(
                key(category[:-len('DETACHMENT')].strip())
                if (category or '').endswith('DETACHMENT') else '')
            if detachment is None:
                # A heading that names no detachment is not fatal when the
                # name is unique in the faction anyway.
                pool = {'stratagem': stratagems, 'enhancement': enhancements}
                everywhere = [r for by_det in pool.get(kind, {}).values()
                              for k2, r in by_det.items() if k2 == name]
                if len(everywhere) == 1:
                    one = everywhere[0]
                    if kind == 'stratagem':
                        return ('stratagems', one['id'], 'id', 'text',
                                one), None
                    if one.get('ability_id'):
                        return ('abilities', one['ability_id'], 'ability_id',
                                'description',
                                by_ability_id.get(one['ability_id'], {})), None
                return None, 'no detachment heading to scope it'

            if kind == 'enhancement':
                found = enhancements[detachment['id']].get(name)
                if not found and owner:
                    # `Through Unity, Devastation Enhancement` is one name with
                    # a comma in it, not an owner and a name.
                    found = enhancements[detachment['id']].get(
                        key(f'{owner}, {parsed.group("name")}'))
                if not found or not found.get('ability_id'):
                    return None, 'no enhancement of that name'
                a = by_ability_id.get(found['ability_id'], {})
                return ('abilities', found['ability_id'], 'ability_id',
                        'description', a), None
            if kind == 'stratagem':
                found = stratagems[detachment['id']].get(name)
                if not found:
                    return None, 'no stratagem of that name'
                return ('stratagems', found['id'], 'id', 'text', found), None

            rule = detachment.get('detachment_rule_id')
            if not rule or name not in ('', key('detachment rule')):
                # `Masters of Manoeuvre Detachment Rule` names the rule itself,
                # and one heading can carry several.
                named = abilities.get(name, [])
                if len(named) == 1:
                    return ('abilities', named[0]['ability_id'], 'ability_id',
                            'description', named[0]), None
            if not rule:
                return None, 'detachment has no rule to correct'
            return ('abilities', rule, 'ability_id', 'description',
                    by_ability_id.get(rule, {})), None

        for correction in corrections:
            category = (correction['category'] or '').strip()
            subject = correction['subject'].strip()
            directive = correction['directive'].rstrip()
            note = f'{pack} pack rules update'

            def emit(target, values):
                # A replacement shorter than a sentence is a truncation, not
                # a rule. Refused rather than shipped.
                if any(isinstance(v, str) and len(v.strip()) < 25
                       for v in values.values()):
                    skipped['the replacement came out too short to be a rule'] += 1
                    return
                if any(isinstance(v, str) and LEAKED.search(v.strip())
                       for v in values.values()):
                    skipped['the replacement has a heading welded to it'] += 1
                    refused.append({'why': 'the replacement has a heading welded to it', 'pack': pack, 'subject': subject, 'directive': directive, 'category': category, 'text': correction['text'][:400]})
                    return
                where, ident, id_key, _, _ = target
                op = {'faction': faction, 'file': where, 'op': 'set',
                      'id': ident, 'values': values, 'note': note}
                if id_key != 'id':
                    op['key'] = id_key
                ops.append(op)

            # --- keywords and core abilities, named for a list of units -----
            parts, base = sections_named(subject)
            part = parts[0] if len(parts) == 1 else None
            if parts and parts[0] in ('keywords', 'abilities') \
                    and not directive.endswith(':'):
                add = ADD_ONE.match(directive)
                swap = SWAP.match(directive)
                if not (add or swap):
                    skipped['a keyword edit that is neither add nor swap'] += 1
                    refused.append({'why': 'a keyword edit that is neither add nor swap', 'pack': pack, 'subject': subject, 'directive': directive, 'category': category, 'text': correction['text'][:400]})
                    continue
                names = [key(n) for n in re.split(r',|\band\b', base)]
                hit = 0
                for n in names:
                    unit = units_by_name.get(n.strip())
                    if not unit:
                        continue
                    hit += 1
                    if part == 'keywords' and add:
                        word = add.group('what').title()
                        if word not in unit.get('keywords', []):
                            ops.append({
                                'faction': faction, 'file': 'units',
                                'op': 'set', 'id': unit['id'],
                                'values': {'keywords':
                                           [*unit.get('keywords', []), word]},
                                'note': note,
                            })
                    elif part == 'abilities' and swap:
                        out_id = next(
                            (a['ability_id'] for a in
                             abilities.get(key(swap.group('out')), [])), None)
                        in_id = next(
                            (a['ability_id'] for a in
                             abilities.get(key(swap.group('in')), [])), None)
                        current = unit.get('ability_ids', [])
                        if not in_id or out_id not in current:
                            continue
                        ops.append({
                            'faction': faction, 'file': 'units', 'op': 'set',
                            'id': unit['id'],
                            'values': {'ability_ids':
                                       [in_id if a == out_id else a
                                        for a in current]},
                            'note': note,
                        })
                if not hit:
                    skipped['no datasheet of that name'] += 1
                    refused.append({'why': 'no datasheet of that name', 'pack': pack, 'subject': subject, 'directive': directive, 'category': category, 'text': correction['text'][:400]})
                continue

            # `Photon Grenades Stratagem, When Section` names a stratagem and
            # a part of it. The part is held aside so what is left still ends
            # with the kind of thing it is, which is what resolution matches.
            # --- a characteristic on a datasheet's profile -------------------
            stat = STATLINE.match(directive)
            if stat and not directive.endswith(':'):
                asked = [f.strip().lower()
                         for f in re.split(r'\band\b|,', stat.group('fields'))]
                # `Archaeopter Fusilave, Archaeopter Stratoraptor – Profiles`
                # names datasheets; `Ynnari Incubi, Melee Weapons, Demiklaives`
                # names a weapon on one. The word `Weapons` is what separates
                # the two, and the weapon is whatever follows it.
                trimmed = re.sub(r'[,\-–—]\s*profiles?\s*$', '', base, flags=re.I)
                weapon_at = re.search(r'\b(?:melee|ranged)\s+weapons\s*,\s*(.+)$',
                                      trimmed, re.I)
                if weapon_at:
                    fields = [WEAPON_FIELDS.get(a) for a in asked]
                    fields = [f for f in fields if f]
                    want = key(re.sub(r'\s*\(.*$', '', weapon_at.group(1)))
                    weapon = next((w for w in bundle.get('weapons', [])
                                   if key(w['name']) == want), None)
                    if weapon and fields:
                        profiles = [dict(pr) for pr in weapon.get('profiles', [])]
                        changed = False
                        for pr in profiles:
                            stats = dict(pr.get('stats') or {})
                            for f in fields:
                                if f in stats:
                                    stats[f] = stat.group('value').strip()
                                    changed = True
                            pr['stats'] = stats
                        if changed:
                            ops.append({'faction': faction, 'file': 'weapons',
                                        'op': 'set', 'id': weapon['id'],
                                        'values': {'profiles': profiles},
                                        'note': note})
                            continue
                    skipped['no weapon profile to change'] += 1
                    refused.append({'why': 'no weapon profile to change',
                                    'pack': pack, 'subject': subject,
                                    'directive': directive,
                                    'category': category,
                                    'text': correction['text'][:400]})
                    continue

                wanted = [STAT_FIELDS.get(a) for a in asked]
                wanted = [w for w in wanted if w]
                names = [key(n) for n in re.split(r',|\band\b|[\-–—]', trimmed)]
                touched = 0
                for n in names:
                    unit = units_by_name.get(n.strip())
                    if not unit or not wanted:
                        continue
                    profiles = unit.get('profiles') or []
                    if not profiles:
                        continue
                    updated = [dict(pr) for pr in profiles]
                    for pr in updated:
                        for w in wanted:
                            if w in pr:
                                pr[w] = stat.group('value').strip()
                    if updated != profiles:
                        touched += 1
                        ops.append({'faction': faction, 'file': 'units',
                                    'op': 'set', 'id': unit['id'],
                                    'values': {'profiles': updated},
                                    'note': note})
                if touched:
                    continue
                skipped['no datasheet profile to change'] += 1
                refused.append({'why': 'no datasheet profile to change',
                                'pack': pack, 'subject': subject,
                                'directive': directive, 'category': category,
                                'text': correction['text'][:400]})
                continue

            # A subject that is nothing but a section name — `Taking Cover
            # Section` — belongs to the rule the heading above it names. The
            # section then identifies a shouted block inside that rule's
            # description rather than a WHEN/TARGET/EFFECT part.
            named_block = None
            if parts and not base:
                phrase = re.match(r'^(?P<part>[\w\' ]+?)\s+sections?\s*$',
                                  subject, re.I)
                named_block = phrase.group('part').strip() if phrase else None
                # Resolved straight from the heading rather than through the
                # subject parser, which needs a name in front of the kind and
                # there is none here.
                owner = detachments.get(
                    key(category[:-len('DETACHMENT')].strip())
                    if category.endswith('DETACHMENT') else '')
                rule = (owner or {}).get('detachment_rule_id')
                target = (('abilities', rule, 'ability_id', 'description',
                           by_ability_id.get(rule, {})), None) if rule \
                    else (None, 'no detachment rule for that heading')
                target, why = target
            else:
                target, why = target_for(base, category)
            if target is None:
                skipped[why] += 1
                refused.append({'why': why, 'pack': pack, 'subject': subject, 'directive': directive, 'category': category, 'text': correction['text'][:400]})
                continue
            _, _, _, field, record = target
            current = (record or {}).get(field) or ''

            # --- one measurement swapped for another ------------------------
            measure = MEASURE.match(directive)
            if measure:
                old, new_value = measure.group('from'), measure.group('to')
                # `Tricksters' Retort Stratagem, Target Section — Change 9" to
                # 8".` means inside the Target section. Counting across the
                # whole rule found the distance twice, or not at all, and
                # refused a correction that was never ambiguous.
                scope = current
                if len(parts) == 1 and parts[0] in TEXT_SECTIONS:
                    found = re.search(
                        r'\*\*' + parts[0].upper() + r':\*\*(.*?)'
                        r'(?=\n\n\*\*[A-Z]+:\*\*|$)', current, re.S)
                    scope = found.group(1) if found else ''
                # The packs write the inch mark straight in some and curly in
                # others; the app's text does the same.
                variants = {old, old.replace('"', '”'), old.replace('”', '"'),
                            old.replace('"', '″')}
                hits = [v for v in variants if scope.count(v) == 1]
                if not hits:
                    # Often the app already has the new value: its wording
                    # comes from Wahapedia, which had made this change. A
                    # correction with nothing left to correct is satisfied,
                    # not refused.
                    already = {new_value, new_value.replace('"', '”'),
                               new_value.replace('”', '"')}
                    if any(v in scope for v in already):
                        skipped['already reads the new value'] += 1
                        continue
                if len(hits) != 1:
                    skipped['the distance is not in the rule exactly once'] += 1
                    refused.append({'why': 'the distance is not in the rule exactly once', 'pack': pack, 'subject': subject, 'directive': directive, 'category': category, 'text': correction['text'][:400]})
                    continue
                hit = hits[0]
                to = new_value if hit == old else \
                    new_value.replace('"', hit[-1])
                if scope is current:
                    emit(target, {field: current.replace(hit, to, 1)})
                else:
                    emit(target, {field: current.replace(
                        scope, scope.replace(hit, to, 1), 1)})
                continue

            # `Change to:` is the instruction whether or not the quotation
            # that follows it starts on the same line, and some packs drop
            # the colon. The verb decides, not the punctuation.
            if not (directive.endswith(':')
                    or re.match(r'^Change to\b', directive)):
                skipped['edits something other than a distance'] += 1
                refused.append({'why': 'edits something other than a distance', 'pack': pack, 'subject': subject, 'directive': directive, 'category': category, 'text': correction['text'][:400]})
                continue

            text = quoted(correction['text'])

            # --- a shouted block inside a rule ------------------------------
            if named_block:
                replaced = replace_named_block(current, named_block, text)
                if replaced is None:
                    skipped['the rule has no block with that heading'] += 1
                    refused.append({'why': 'the rule has no block with that heading',
                                    'pack': pack, 'subject': subject,
                                    'directive': directive, 'category': category,
                                    'text': correction['text'][:400]})
                    continue
                emit(target, {field: replaced})
                continue

            # --- one or more named sections of a rule -----------------------
            if parts:
                if any(p not in TEXT_SECTIONS for p in parts):
                    skipped['names a part of a datasheet, not of a rule'] += 1
                    refused.append({'why': 'names a part of a datasheet, not of a rule', 'pack': pack, 'subject': subject, 'directive': directive, 'category': category, 'text': correction['text'][:400]})
                    continue
                # `Target and Effect Sections` quotes both replacements in one
                # block, each under its own heading, so the block is split on
                # the headings rather than shared between them.
                replaced = current
                for p_name in parts:
                    piece = re.search(
                        r'\*\*' + p_name.upper() + r':\*\*(.*?)'
                        r'(?=\*\*(?:' + '|'.join(
                            x.upper() for x in TEXT_SECTIONS) + r'):\*\*|$)',
                        text, re.S | re.I)
                    body = piece.group(1) if piece else text
                    step = replace_section(replaced, p_name, body)
                    if step is None:
                        replaced = None
                        break
                    replaced = step
                if replaced is None:
                    skipped['the rule has no such section'] += 1
                    refused.append({'why': 'the rule has no such section', 'pack': pack, 'subject': subject, 'directive': directive, 'category': category, 'text': correction['text'][:400]})
                    continue
                emit(target, {field: replaced})
                continue

            # --- the whole rule ---------------------------------------------
            emit(target, {field: text})

    with open(f'{ROOT}/data/faction-pack-updates-unapplied.json', 'w') as f:
        json.dump(refused, f, indent=1, ensure_ascii=False)
        f.write('\n')
    return ops, skipped





# ------------------------------------------------------------------- points

"""Points, and who can lead whom, from the Munitorum Field Manual.

The MFM is Games Workshop's own and is updated with each rules pass; the
community sources are not. It publishes three things the app holds and cannot
get elsewhere: what a unit costs at each size, what a detachment's
enhancements cost, and — in a `LEADER` block on each character's card — which
datasheets that character can attach to.

Two shapes have to be respected when writing points back. A unit priced by
how many of it you have already taken carries two blocks, `YOUR 1ST TO 2ND
UNITS COST` and `YOUR 3RD + UNIT COSTS`, and the app stores those as separate
entries for the same model count. And `WARGEAR OPTIONS` on the same card is
priced per item and is not a unit cost at all.
"""

MFM = f'{ROOT}/data/mfm-points.json'
# The MFM's slug for a faction, where it differs from the app's id.
MFM_SLUG = {'space-marines': 'adeptus-astartes',
            'imperial-agents': 'agents-of-the-imperium'}
MODELS = re.compile(r'(\d+)\s*model')


def points_ops():
    if not os.path.exists(MFM):
        return [], collections.Counter()

    mfm = json.load(open(MFM))
    files = bundled()
    ops, stats = [], collections.Counter()
    # A Space Marine chapter's page lists its parent's datasheets, so the same
    # record is described by a dozen pages. One operation per record: the
    # first page to say it wins, and a page that says something different is
    # counted rather than allowed to overwrite it.
    written = {}

    def once(op):
        at = (op['faction'], op['file'], op['id'])
        if at in written:
            if written[at]['values'] != op['values']:
                stats['pages disagree about this record'] += 1
            return False
        written[at] = op
        ops.append(op)
        return True

    def parent_of(fid):
        for f in files.get(fid, {}).get('factions', []):
            if f.get('id') == fid:
                return f.get('parent_faction_id')
        return None

    for slug, data in sorted(mfm.items()):
        faction = MFM_SLUG.get(slug, slug)
        bundle = files.get(faction)
        if bundle is None:
            stats['no bundle for this faction'] += 1
            continue
        parent = parent_of(faction)

        # A Space Marine chapter's MFM page lists its parent's datasheets. The
        # operation has to name the faction whose bundle actually carries the
        # record, or it lands nowhere.
        owner, units = {}, {}
        for u in bundle['units']:
            units[key(u['name'])] = u
            owner[key(u['name'])] = faction
        if parent in files:
            for u in files[parent]['units']:
                units.setdefault(key(u['name']), u)
                owner.setdefault(key(u['name']), parent)

        attachments = {}
        for row in bundle.get('leader-attachments', []):
            attachments[row['leader_id']] = row

        for entry in data['units']:
            record = units.get(key(entry['name']))
            if record is None:
                stats['no datasheet of that name'] += 1
                continue
            at = owner[key(entry['name'])]

            # Grouped by model count and then by scope, which is the order the
            # app's own records are in.
            counts, priced = [], collections.defaultdict(list)
            for block in entry['costs']:
                for tier in block['tiers']:
                    found = MODELS.search(tier['of'])
                    if not found:
                        continue
                    n = int(found.group(1))
                    if n not in priced:
                        counts.append(n)
                    priced[n].append(tier['cost'])
            wanted = [{'models': n, 'cost': c}
                      for n in counts for c in priced[n]]
            if not wanted:
                stats['no model counts on the card'] += 1
                continue

            current = record.get('points') or []
            if sorted(p.get('cost') for p in current) != \
                    sorted(p['cost'] for p in wanted):
                if once({'faction': at, 'file': 'units', 'op': 'set',
                         'id': record['id'], 'values': {'points': wanted},
                         'note': 'Munitorum Field Manual'}):
                    stats['points corrected'] += 1

            if entry.get('leader'):
                targets = [units[key(n)]['id'] for n in entry['leader']
                           if key(n) in units]
                if len(targets) != len(entry['leader']):
                    stats['a unit it can lead is not in the app'] += 1
                if not targets:
                    continue
                row = attachments.get(record['id'])
                have = sorted(row.get('eligible_bodyguard_ids') or []) \
                    if row else []
                if sorted(targets) == have:
                    continue
                if once({
                    'faction': faction, 'file': 'leader-attachments',
                    'op': 'set' if row else 'add', 'id': record['id'],
                    'key': 'leader_id',
                    'values': {'eligible_bodyguard_ids': targets},
                    'note': 'Munitorum Field Manual, LEADER section',
                }):
                    stats['leader list corrected' if row
                          else 'leader list added'] += 1

        detachments = {key(d['name']): d for d in bundle.get('detachments', [])}
        costs = collections.defaultdict(dict)
        for e in bundle.get('enhancements', []):
            costs[e.get('detachment_id')][key(e['name'])] = e
        for d in data['detachments']:
            record = detachments.get(key(d['name']))
            if record is None:
                continue
            for e in d['enhancements']:
                found = costs[record['id']].get(key(e['name']))
                if found is None or str(found.get('cost')) == str(e['cost']):
                    continue
                if once({'faction': faction, 'file': 'enhancements',
                         'op': 'set', 'id': found['id'],
                         'values': {'cost': str(e['cost'])},
                         'note': 'Munitorum Field Manual'}):
                    stats['enhancement cost corrected'] += 1

    return ops, stats





# --------------------------------------------------------------- datasheets

"""Datasheets from the packs: new units, corrected statlines, Legends.

Three sections of every pack use one layout — `Datasheets`, `Imperial Armour
Datasheets` and `Legends Datasheets` — and `parse-datasheets.py` reads all
three. What separates them here is what the app is told about the result: a
Legends datasheet arrives with `is_legend`, so the builder keeps hiding it
behind the existing setting, and an Imperial Armour one is marked as Forge
World's so a reader can see which book it came from.

A statline is only written when it is complete and the app's disagrees, and a
weapon only when the app already has one by that name — minting weapon ids
for 1,542 profiles is a bigger change than a patch should make, and a unit
whose weapons are half-linked is worse than one the app already draws.
"""

DATASHEETS = f'{ROOT}/data/faction-pack-datasheets.json'
STAT_KEYS = ('M', 'T', 'SV', 'W', 'LD', 'OC')
# What the app calls the two sections that are not the plain codex.
KIND_SOURCE = {'imperial-armour': 'forge-world', 'legends': 'legends'}


def datasheet_ops(packs_to_factions):
    if not os.path.exists(DATASHEETS):
        return [], collections.Counter()

    sheets = json.load(open(DATASHEETS))
    files = bundled()
    ops, stats = [], collections.Counter()

    for pack, found in sorted(sheets.items()):
        faction = packs_to_factions.get(pack, pack)
        bundle = files.get(faction)
        if bundle is None:
            stats['no bundle for this pack'] += len(found)
            continue
        units = {key(u['name']): u for u in bundle['units']}
        weapons = {key(w['name']): w for w in bundle.get('weapons', [])}

        for sheet in found:
            record = units.get(key(sheet['name']))
            profile = sheet.get('profile') or {}

            if record is None:
                if not profile:
                    stats['new, but its statline did not parse'] += 1
                    continue
                ops.append({
                    'faction': faction, 'file': 'units', 'op': 'add',
                    'id': slug(sheet['name']),
                    'values': {
                        'name': sheet['name'].title(),
                        'faction_id': faction,
                        'keywords': sheet['keywords'],
                        'faction_keywords': sheet['faction_keywords'],
                        'profiles': [{'name': sheet['name'].title(),
                                      **{k: profile[k] for k in STAT_KEYS
                                         if k in profile}}],
                        'is_legend': sheet['kind'] == 'legends',
                        **({'sources': [KIND_SOURCE[sheet['kind']]]}
                           if sheet['kind'] in KIND_SOURCE else {}),
                        'game_version': {'edition': '11th',
                                         'dataslate': 'faction-pack-2026-08'},
                    },
                    'note': f'{pack} pack, {sheet["kind"]} datasheet',
                })
                stats[f'added ({sheet["kind"]})'] += 1
                continue

            values = {}
            current = (record.get('profiles') or [{}])[0]
            if profile:
                wanted = {k: profile[k] for k in STAT_KEYS if k in profile}
                # `12` and `12"` are the same move; only a real disagreement
                # is worth writing, and a field the app leaves empty is one.
                def same(a, b):
                    return str(a).replace('"', '').strip() == \
                        str(b).replace('"', '').strip()
                if any(not same(current.get(k), v) for k, v in wanted.items()):
                    values['profiles'] = [{**current, **wanted}]
            if sheet['keywords'] and \
                    sorted(k.lower() for k in sheet['keywords']) != \
                    sorted(k.lower() for k in (record.get('keywords') or [])):
                values['keywords'] = sheet['keywords']
            # **Never** flag an existing record as Legends from a name match.
            # A pack's Legends section carries datasheets whose names collide
            # with current ones — Captain, Warboss, Librarian, Chaos Lord —
            # and setting the flag on those would hide five core datasheets
            # per faction from the builder. The flag is only ever set on a
            # datasheet this patch adds, where there is nothing to collide
            # with.
            if sheet['kind'] == 'legends' and not record.get('is_legend'):
                stats['a Legends name that a current datasheet already has'] += 1

            if values:
                ops.append({'faction': faction, 'file': 'units', 'op': 'set',
                            'id': record['id'], 'values': values,
                            'note': f'{pack} pack, {sheet["kind"]} datasheet'})
                stats['datasheet corrected'] += 1

            for table in sheet['weapons'].values():
                for name, line in table:
                    weapon = weapons.get(key(re.sub(r'\s*\[.*$', '', name)))
                    if weapon is None:
                        stats['weapon not in the app'] += 1
                        continue
                    profiles = [dict(p) for p in weapon.get('profiles', [])]
                    if len(profiles) != 1:
                        stats['weapon has several profiles'] += 1
                        continue
                    got = dict(profiles[0].get('stats') or {})
                    # The packs print a skill as `5+` and a strength as `4`;
                    # the app stores `5` and `4`, and adds the plus when it
                    # draws. So the two are compared as numbers, and only a
                    # stat that really changed is written — in the app's own
                    # form. Comparing the printed strings instead reported 481
                    # differences where nearly all were `5` against `5+` or an
                    # int against the same int as text, and writing those back
                    # would have drawn `5++`.
                    # Only a skill's plus is notation the app adds when it
                    # draws. `D3+3` attacks and `D6+1` damage are dice, and
                    # stripping their plus turns a real value into a wrong
                    # one.
                    def plain(value, field=''):
                        text_value = str(value).strip().replace('"', '')
                        if field in ('BS', 'WS'):
                            text_value = text_value.rstrip('+')
                        try:
                            return int(text_value)
                        except ValueError:
                            return text_value

                    want = {}
                    for k, v in line.items():
                        if k == 'RANGE' or k not in got:
                            continue
                        if plain(got[k], k) != plain(v, k):
                            want[k] = plain(v, k) if isinstance(got[k], int) \
                                else str(plain(v, k))
                    # Belt and braces: if the result reads the same as what
                    # is already there, there is nothing to write. Type churn
                    # — an int becoming the same int as text — is not a
                    # correction, and every operation this patch carries
                    # should change something a player can see.
                    merged = {**got, **want}
                    if {k: plain(v, k) for k, v in merged.items()} == \
                            {k: plain(v, k) for k, v in got.items()}:
                        stats['weapon already reads the same'] += 1
                        continue
                    profiles[0]['stats'] = merged
                    ops.append({'faction': faction, 'file': 'weapons',
                                'op': 'set', 'id': weapon['id'],
                                'values': {'profiles': profiles},
                                'note': f'{pack} pack datasheet'})
                    stats['weapon profile corrected'] += 1

    # One operation per record: a weapon is printed on every datasheet that
    # carries it, and the same unit can appear in two sections.
    seen, unique = set(), []
    for op in ops:
        at = (op['faction'], op['file'], op['id'])
        if at in seen:
            stats['already written by another datasheet'] += 1
            continue
        seen.add(at)
        unique.append(op)
    return unique, stats





# --------------------------------------------------------------------- faqs

"""The packs' FAQs, carried as text (§3.16).

Nothing is interpreted. There is no record in the app a FAQ corrects — it
answers how two rules interact, and deriving a rule change from that would be
the app adjudicating rather than quoting. They ship as their own file so the
Rules page can show a player the ones for the faction they are playing.
"""

FAQS = f'{ROOT}/data/faction-pack-faqs.json'


def faq_ops(packs_to_factions):
    if not os.path.exists(FAQS):
        return [], collections.Counter()

    faqs = json.load(open(FAQS))
    files = bundled()
    ops, stats = [], collections.Counter()
    for pack, questions in sorted(faqs.items()):
        faction = packs_to_factions.get(pack, pack)
        if faction not in files:
            stats['no bundle for this pack'] += len(questions)
            continue
        for i, entry in enumerate(questions, start=1):
            ops.append({
                'faction': faction, 'file': 'faqs', 'op': 'add',
                'id': f'{PATCH_ID}-{i:02d}',
                'values': {'question': entry['question'],
                           'answer': entry['answer'],
                           'source': 'Faction Pack, 26 August 2026'},
                'note': f'{pack} pack FAQ',
            })
            stats['question'] += 1
    return ops, stats


def strip_stray_pluses(ops):
    """No operation may give a skill a plus the app does not already store.

    The app adds one when it draws, so writing the printed `4+` back shows
    `4++`. Applied over everything generated rather than inside one phase:
    the case that got through came from the errata handler, not the datasheet
    one, and a guard that lives in a single phase only guards that phase.

    A dice expression keeps its plus — `D3+3` attacks and `D6+1` damage are
    values, not notation.
    """
    files = bundled()
    for op in ops:
        if op['file'] != 'weapons':
            continue
        record = next((w for w in files.get(op['faction'], {}).get('weapons', [])
                       if w['id'] == op['id']), None)
        here = ((record or {}).get('profiles') or [{}])[0].get('stats') or {}
        for profile in op['values'].get('profiles', []):
            for skill in ('BS', 'WS'):
                value = profile.get('stats', {}).get(skill)
                if value is None or '+' not in str(value):
                    continue
                if '+' in str(here.get(skill, '')):
                    continue
                text = str(value).rstrip('+')
                profile['stats'][skill] = int(text) if text.isdigit() else text
    return ops





# -------------------------------------------------------------- base sizes

"""Base sizes from the Warhammer Event Companion's guide (§3.17).

Forty pages at the back of the Companion list every datasheet's base. The app
has a `base_size_mm` field and nothing else published fills it: **820 of the
932 it already had agree exactly**, which is what says the extraction can be
trusted, and the 112 that do not are the reason to carry it.
"""

BASE_SIZES = f'{ROOT}/data/event-companion-base-sizes.json'
BASE_FACTION = {'space-marines': 'adeptus-astartes',
                'imperial-agents': 'agents-of-the-imperium'}


def base_size(text):
    """`25mm`, `105 x 70mm` and `Hull`, in the shape the app already stores.

    Two details are the app's convention rather than the guide's. The first
    number of an oval is its **width** — 820 records already read that way,
    and writing `120 x 92mm` as length-then-width would have silently turned
    every oval base ninety degrees. And a whole number is stored as an
    integer, so `40.0` is not written over `40`.
    """
    def number(value):
        as_float = float(value)
        return int(as_float) if as_float == int(as_float) else as_float

    plain = text.strip().lower()
    if plain == 'hull':
        return {'shape': 'hull'}
    oval = re.match(r'^(\d+(?:\.\d+)?)\s*x\s*(\d+(?:\.\d+)?)\s*mm', plain)
    if oval:
        return {'shape': 'oval', 'width': number(oval.group(1)),
                'length': number(oval.group(2))}
    round_ = re.match(r'^(\d+(?:\.\d+)?)\s*mm', plain)
    if round_:
        return {'shape': 'round', 'diameter': number(round_.group(1))}
    return None


def base_size_ops():
    if not os.path.exists(BASE_SIZES):
        return [], collections.Counter()

    guide = json.load(open(BASE_SIZES))
    files = bundled()
    ops, stats = [], collections.Counter()
    for faction, rows in sorted(guide.items()):
        fid = slug(faction.replace('’', ''))
        fid = BASE_FACTION.get(fid, fid)
        bundle = files.get(fid)
        if bundle is None:
            stats['no bundle for this faction'] += 1
            continue
        units = {key(u['name']): u for u in bundle['units']}
        for row in rows:
            record = units.get(key(row['name']))
            if record is None:
                stats['datasheet not in the app'] += 1
                continue
            wanted = base_size(row['base'])
            if wanted is None:
                stats['base size not understood'] += 1
                continue
            current = record.get('base_size_mm')
            if current and all(current.get(k) == v
                               for k, v in wanted.items()):
                stats['already agrees'] += 1
                continue
            ops.append({'faction': fid, 'file': 'units', 'op': 'set',
                        'id': record['id'],
                        'values': {'base_size_mm': wanted},
                        'note': 'Warhammer Event Companion base size guide'})
            stats['filled in' if not current else 'corrected'] += 1
    return ops, stats


if __name__ == '__main__':
    rules_ops, skipped = rules_update_ops(PACK_TO_FACTION)
    ops.extend(rules_ops)
    mfm_ops, mfm_stats = points_ops()
    ops.extend(mfm_ops)
    sheet_ops, sheet_stats = datasheet_ops(PACK_TO_FACTION)
    ops.extend(sheet_ops)
    faq_operations, faq_stats = faq_ops(PACK_TO_FACTION)
    ops.extend(faq_operations)
    base_ops, base_stats = base_size_ops()
    ops.extend(base_ops)

    strip_stray_pluses(ops)

    patch = {
        'id': PATCH_ID,
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
    print(f'\nfrom the Munitorum Field Manual: {len(mfm_ops)} applied')
    for k, v in mfm_stats.most_common():
        print(f'   {k:38} {v}')
    print(f'\nfrom the datasheets: {len(sheet_ops)} applied')
    for k, v in sheet_stats.most_common():
        print(f'   {k:38} {v}')
    print(f'\nFAQs carried: {len(faq_operations)}')
    for k, v in faq_stats.most_common():
        print(f'   {k:38} {v}')
    print(f'\nbase sizes: {len(base_ops)} applied')
    for k, v in base_stats.most_common():
        print(f'   {k:38} {v}')
    print(f'\nfactions touched {len({o["faction"] for o in ops})}')
