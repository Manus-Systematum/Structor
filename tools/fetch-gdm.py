#!/usr/bin/env python3
"""Fetch mission card text from gdmissions.app into data/gdm/cards.json.

The site is a Next.js app that renders its cards client-side, but the card
data travels in the server payload of each card page as structured JSON —
sections with a trigger, and tiers with the printed sentence and its VP. That
is what this reads. It does not scrape rendered HTML, and it does not touch
the card images.

The site publishes no licence, no terms and no attribution; DESIGN.md §3.11
records the decision to use it anyway and who made it.

Usage:  tools/fetch-gdm.py            # refresh data/gdm/cards.json
        tools/fetch-gdm.py --check    # fetch and report, write nothing
"""
import json
import os
import re
import sys
import time
import urllib.request

BASE = 'https://gdmissions.app'
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'data', 'gdm', 'cards.json')

DECKS = ['take-and-hold', 'purge-the-foe', 'reconnaissance',
         'priority-assets', 'disruption']


def get(path):
    req = urllib.request.Request(
        BASE + path,
        headers={'User-Agent': 'Structor/1.0 (personal 40k companion app)'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode('utf-8', 'replace')


def payload(html):
    """The Next.js flight payload, reassembled.

    Each push carries a JS string literal; decoding with `json.loads` handles
    the escaping properly. Decoding with `unicode_escape` does not, and
    quietly mangles every apostrophe in the card text.
    """
    parts = []
    for m in re.finditer(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)',
                         html, re.S):
        try:
            parts.append(json.loads(m.group(1)))
        except ValueError:
            pass
    return ''.join(parts)


def extract(text, key):
    """The JSON object following `"key":` in the payload, by brace matching.

    The payload is a React flight stream, not a JSON document, so it cannot be
    parsed whole — the card object has to be cut out of it.
    """
    at = text.find('"%s":{' % key)
    if at < 0:
        return None
    start = at + len(key) + 3
    depth, i, in_str, esc = 0, start, False, False
    while i < len(text):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(text[start:i + 1])
                except ValueError:
                    return None
        i += 1
    return None


def links(html, prefix):
    return sorted(set(re.findall(r'"(%s/[a-z0-9\-]+)"' % re.escape(prefix),
                                 html)))


def main():
    check = '--check' in sys.argv
    cards = {'primary': {}, 'secondary': {}}
    missing = []

    for deck in DECKS:
        listing = get('/11th/primary-missions/' + deck)
        for href in links(listing, '/11th/primary-missions/' + deck):
            slug = href.rsplit('/', 1)[-1]
            card = extract(payload(get(href)), 'primary')
            if card is None:
                missing.append(href)
                continue
            cards['primary']['%s/%s' % (deck, slug)] = card
            time.sleep(0.2)

    listing = get('/11th/secondary-missions')
    for href in links(listing, '/11th/secondary-missions'):
        slug = href.rsplit('/', 1)[-1]
        card = extract(payload(get(href)), 'secondary')
        if card is None:
            missing.append(href)
            continue
        cards['secondary'][slug] = card
        time.sleep(0.2)

    print('primary %d, secondary %d, unreadable %d'
          % (len(cards['primary']), len(cards['secondary']), len(missing)))
    for href in missing:
        print('  MISS', href)

    if check:
        return
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        json.dump(cards, f, indent=2, ensure_ascii=False, sort_keys=True)
        f.write('\n')
    print('wrote', os.path.relpath(OUT, ROOT))


if __name__ == '__main__':
    main()
