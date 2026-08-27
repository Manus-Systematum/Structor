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
TITLE = re.compile(r'<div class="[^"]*bg-slate-500[^"]*">(.*?)</div>', re.S)
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
ROW = re.compile(r'<li[^>]*>\s*<span[^>]*>([^<]*?)</span>\s*'
                 r'<span[^>]*>([\d,]+)\s*pts</span>', re.S)

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
    """The streamed page, with every deferred block put where it belongs."""
    blocks = {m.group('id'): m.group('body') for m in HIDDEN.finditer(page)}
    for m in RESOLVE.finditer(page):
        body = blocks.get(m.group('from'))
        if body is None:
            continue
        page = page.replace(f'<template id="{m.group("to")}"></template>', body)
    return page


def text(raw):
    return html.unescape(re.sub(r'<[^>]+>', '', raw)).strip()


def fetch(slug):
    req = urllib.request.Request(f'{BASE}/{slug}', headers={'User-Agent': AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode('utf-8', errors='replace')


def parse(page):
    units, detachments = [], []
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

        if costs:
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
