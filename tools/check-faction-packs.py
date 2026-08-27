#!/usr/bin/env python3
"""Does the parse agree with the packs' own contents pages?

Run this before `make-update.py`, and read it. The failure it exists to catch
is that a detachment which parsed to nothing looks exactly like a detachment
the pack gives no stratagems — and the difference decides whether the app
deletes real stratagems out of somebody's army.

Two detachments do legitimately have none, Sanctified Orators and Librarius
Conclave, both confirmed by rendering the page and looking at it. Anything
else in that list is a parser fault, not a fact about the rules.
"""
import collections, json, os, re

def key(s):
    return re.sub(r'[^a-z0-9]+', '', (s or '').lower())

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
parsed = json.load(open(f'{ROOT}/data/faction-packs.json'))
contents = json.load(open(f'{ROOT}/data/faction-pack-detachments.json'))

bad = 0
for pack in sorted(parsed):
    strats = parsed[pack]
    listed = {key(d['name']): d['name'] for d in contents.get(pack, [])}
    found = collections.Counter(key(s['detachment']) for s in strats)

    unlisted = [s['detachment'] for s in strats if key(s['detachment']) not in listed]
    empty = [n for k, n in listed.items() if not found[k]]
    noCp = [s['name'] for s in strats if s['cp'] is None]
    noText = [s['name'] for s in strats if not s['text']]
    dupes = [n for n, c in collections.Counter(
        (key(s['detachment']), key(s['name'])) for s in strats).items() if c > 1]

    notes = []
    if unlisted:
        notes.append(f'{len(set(unlisted))} not on the contents page: '
                     + ', '.join(sorted(set(unlisted))))
    if empty:
        notes.append(f'{len(empty)} listed with no stratagems found: '
                     + ', '.join(sorted(empty)))
    if noCp:
        notes.append(f'{len(noCp)} with no cost: ' + ', '.join(noCp))
    if noText:
        notes.append(f'{len(noText)} with no effect text: ' + ', '.join(noText))
    if dupes:
        notes.append(f'{len(dupes)} duplicated')
    if notes:
        bad += 1
        print(f'== {pack}')
        for n in notes:
            print('   ' + n)

print(f'\n{sum(len(v) for v in parsed.values())} stratagems across '
      f'{len(parsed)} packs; {bad} packs with something to look at')
