#!/usr/bin/env python3
"""Fetch stratagem rules text into data/stratagem-text/.

Two sources, because neither alone is both complete and current:

  * **Wahapedia's 11th edition data export** — 1,668 stratagems with full
    WHEN / TARGET / EFFECT / RESTRICTIONS text, updated within days. Its
    export page states the terms outright: "The export data can be used to
    research game mechanics and develop related interfaces. When publishing
    your work, mentioning Wahapedia is highly recommended." robots.txt
    disallows `/wh40k11ed_/`, a staging path; the export at `/wh40k11ed/`
    is not disallowed.

  * **pguetschow/warhammer-40k-stratagem-card-generator** — the eleven core
    stratagems, transcribed from Games Workshop's own free Core Rules PDF.

Wahapedia carries several rows per core stratagem name: a Boarding Actions
variant, a legacy 10th edition one, and the current `Core Stratagem`. Reading
the first row rather than the right one is why the export first looked stale.

Usage:  tools/fetch-stratagem-text.py
"""
import json
import os
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'data', 'stratagem-text')

WAHAPEDIA = 'https://wahapedia.ru/wh40k11ed/Stratagems.csv'
CORE_PDF = ('https://raw.githubusercontent.com/pguetschow/'
            'warhammer-40k-stratagem-card-generator/main/public/data/11/cards.json')


def fetch(url):
    req = urllib.request.Request(
        url, headers={'User-Agent': 'Structor/1.0 (personal 40k companion app)'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    os.makedirs(OUT, exist_ok=True)

    csv_bytes = fetch(WAHAPEDIA)
    with open(os.path.join(OUT, 'wahapedia-stratagems.csv'), 'wb') as f:
        f.write(csv_bytes)
    print('wahapedia: %d KB' % (len(csv_bytes) // 1024))

    core = fetch(CORE_PDF)
    with open(os.path.join(OUT, 'core-stratagems.json'), 'wb') as f:
        f.write(core)
    parsed = json.loads(core)
    cards = [c for faction in parsed['factions'].values()
             for cards in faction['detachments'].values() for c in cards]
    print('core rules PDF: %d stratagems (%s)'
          % (len(cards), parsed.get('lastUpdate')))


if __name__ == '__main__':
    main()
