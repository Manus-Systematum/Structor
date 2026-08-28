#!/usr/bin/env python3
"""Points from Games Workshop's Munitorum Field Manual.

The pages are server-rendered, but **streamed out of order**, which is what
made an earlier pass in this project conclude the units were not there at all.
Two things hid them. The whole document is one line, so `grep -c` counts one
and reads like two matches instead of eighty-two. And React sends the skeleton
first with `<template id="P:7a"></template>` where each name and cost goes,
then the content later in `<div hidden id="S:7a">…</div>`, with a
`<script>$RS("S:7a","P:7a")</script>` that splices the two together in the
browser.

So the splice is done here before anything is parsed. Nothing is missing from
the response; it just is not in reading order.

A unit card looks like:

    <div class="...bg-slate-500...text-xl...">AESTRED THURGA AND AGATHAE DOLAN</div>
    ...YOUR UNIT COSTS...
    <ul ...><li><span>2 models</span><span>80 pts</span></li></ul>

and a detachment card carries `NDP` and an `ENHANCEMENTS` list instead. Both
are read; the app holds points for both.
"""
import html
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = f'{ROOT}/data/mfm-points.json'
BASE = 'https://mfm.warhammer-community.com/en'
AGENT = 'Structor/1.0 (personal 40k companion app)'

CARD = re.compile(r'<div class="flex flex-col space-y-1 m-1[^"]*">(.*?)'
                  r'(?=<div class="flex flex-col space-y-1 m-1|$)', re.S)
# A card's title bar is grey — except on a unit whose points **changed in
# this update**, which gets a red one and a ▲/▼ badge beside the name. Reading
# only the grey bar skipped exactly the units the update is about: the T'au
# page has 43 cards, and the three it hid were Crisis Starscythes, Tiger Shark
# and The Twin Lance.
TITLE = re.compile(
    r'<div class="[^"]*bg-(?:slate-500|red-500)[^"]*">(.*?)</div>', re.S)
# On a detachment card the title shares its div with the `2DP` badge.
TITLE_SPAN = re.compile(r'<span[^>]*>(.*?)</span>', re.S)

# A card is a run of labelled blocks. `YOUR UNIT COSTS` is a flat price list;
# `YOUR 1ST TO 2ND UNITS COST` and `YOUR 3RD + UNIT COSTS` are the same unit
# priced by how many of it you have already taken; `WARGEAR OPTIONS` is per
# item and is not a unit price at all. Reading them as one list put a
# meltagun's 5 points in with the squad's, and put a squad's two size tiers in
# the wrong order.
BLOCK = re.compile(
    r'<div class="[^"]*bg-slate-200[^"]*"[^>]*>(?:<span[^>]*>)?'
    r'(?P<label>[A-Z][A-Z0-9 \'’+/-]*?)(?:</span>)?(?:<img[^>]*>)?</div>'
    r'(?P<body>.*?)(?=<div class="[^"]*bg-slate-200|$)', re.S)
# A changed price is written `▲ (+10) 230 pts` in its own coloured span, so
# the figure is not the whole of the text. The delta is dropped: the app holds
# what a unit costs, and what it cost last month is not a second price.
ROW = re.compile(r'<li[^>]*>\s*<span[^>]*>([^<]*?)</span>\s*'
                 r'<span[^>]*>\s*(?:[▲▼]\s*\([+-]?[\d,]+\)\s*)?'
                 r'([\d,]+)\s*pts</span>', re.S)

DP = re.compile(r'<span class="text-sm self-end pl-2">(\d+)DP</span>')
# `LEADER` and `SUPPORT` head a list of the datasheets a character can attach
# to. The app holds the same thing as leader-attachments, and nothing else
# publishes it in one place.
ATTACH = re.compile(r'<span[^>]*>(?P<role>LEADER|SUPPORT)</span>.*?</div>\s*'
                    r'<span[^>]*>(?P<targets>.*?)</span>', re.S)
ENH = re.compile(r'<li[^>]*>(?:(?!</li>).)*?<span[^>]*>([^<]+?)</span>'
                 r'(?:(?!</li>).)*?([\d,]+)\s*pts', re.S)


RESOLVE = re.compile(r'\$RS\("(?P<from>[^"]+)"\s*,\s*"(?P<to>[^"]+)"\)')
HIDDEN = re.compile(r'<div hidden id="(?P<id>S:[^"]+)">(?P<body>.*?)</div>'
                    r'(?=<script>|<div hidden id=)', re.S)


def splice(page):
    """The streamed page, with every deferred block put where it belongs.

    The blocks are copied into place and **left where they were streamed as
    well**, because for these pages the tail is the document: the head holds
    the detachment cards and a template for nothing else, and every unit card
    arrives later. Reading the tail is therefore not a mistake, but its blocks
    have to be kept apart from each other.

    Hence the marker. A block that is a whole card carries its own wrapper; a
    block that is a *fragment* — a title whose card streamed earlier, a price
    list whose title has not streamed yet — carries none, and without a
    boundary it is read as more of whichever card precedes it. That is how
    Vespid Stingwings came to cost "5 models 70 pts, 10 models 115 pts,
    1 model 50 pts" and to lead Breacher Teams: the 50 and the leader list are
    the next card's. Marked, a fragment is its own card — one with no title,
    or no prices, and either way not something to read.

    Names still arrive twice, once in place and once in the tail. `parse`
    keeps the first.
    """
    blocks = {m.group('id'): m.group('body') for m in HIDDEN.finditer(page)}
    for m in RESOLVE.finditer(page):
        body = blocks.get(m.group('from'))
        if body is None:
            continue
        page = page.replace(f'<template id="{m.group("to")}"></template>', body)

    return page.replace('<div hidden id="S:',
                        '<div class="flex flex-col space-y-1 m-1" '
                        'hidden id="S:')


def text(raw):
    return html.unescape(re.sub(r'<[^>]+>', '', raw)).strip()


def fetch(slug):
    req = urllib.request.Request(f'{BASE}/{slug}', headers={'User-Agent': AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode('utf-8', errors='replace')


def parse(page):
    units, detachments = [], []
    # `splice` copies each deferred block into place and leaves the original
    # `<div hidden>` where it was, so every card is in the page twice. Both
    # copies say the same thing; the second is dropped rather than parsed into
    # a duplicate entry.
    seen = set()
    for card in CARD.findall(page):
        title = TITLE.search(card)
        if not title:
            continue
        inner = TITLE_SPAN.search(title.group(1))
        name = text(inner.group(1) if inner else title.group(1))
        if not name:
            continue

        costs, wargear = [], []
        for block in BLOCK.finditer(card):
            label = block.group('label').strip()
            rows = [{'of': text(what), 'cost': int(cost.replace(',', ''))}
                    for what, cost in ROW.findall(block.group('body'))]
            if not rows:
                continue
            if 'WARGEAR' in label:
                wargear.extend(rows)
            elif 'COST' in label:
                costs.append({'scope': label, 'tiers': rows})

        if name in seen:
            continue

        if costs:
            seen.add(name)
            attaches = {}
            for role, targets in ATTACH.findall(card):
                names = [t.strip() for t in text(targets).split(',')]
                attaches[role.lower()] = [n for n in names if n]
            units.append({
                'name': name, 'costs': costs,
                **({'wargear': wargear} if wargear else {}),
                **attaches,
            })
        elif DP.search(card):
            seen.add(name)
            body = card[card.find('ENHANCEMENTS'):] if 'ENHANCEMENTS' in card \
                else ''
            detachments.append({
                'name': name,
                'dp': int(DP.search(card).group(1)),
                'enhancements': [
                    {'name': text(n), 'cost': int(c.replace(',', ''))}
                    for n, c in ENH.findall(body)
                ],
            })
    return units, detachments


def main():
    slugs = sys.argv[1:]
    if not slugs:
        index = fetch('')
        slugs = sorted({m for m in re.findall(r'/en/([a-z0-9-]+)"', index)
                        if m not in ('en',)})
    out = json.load(open(OUT)) if os.path.exists(OUT) else {}
    for slug in slugs:
        try:
            units, detachments = parse(splice(fetch(slug)))
        except Exception as err:  # noqa: BLE001 - reported, not swallowed
            print(f'{slug:26} FAILED {err}', flush=True)
            continue
        if not units and not detachments:
            print(f'{slug:26} nothing parsed', flush=True)
            continue
        out[slug] = {'units': units, 'detachments': detachments}
        print(f'{slug:26} {len(units):3} units  {len(detachments):2} detachments',
              flush=True)
        time.sleep(1)
    with open(OUT, 'w') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write('\n')
    print(f'\n-> {OUT}')


if __name__ == '__main__':
    main()
