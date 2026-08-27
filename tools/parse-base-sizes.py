#!/usr/bin/env python3
"""The Base Size Guide from the Warhammer Event Companion.

Forty pages at the back of the Companion list every datasheet's base, by
faction — a two-column table of a name and a size, aligned by baseline. The
app has a `base_size_mm` field for exactly this and nothing published fills
it.

A size is not always a number: `Hull` for a vehicle that has none, `Oval`
sizes written `105 x 70mm`, and a few units whose entry names two bases
because the datasheet has two models. All are kept as printed.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pdf_columns  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = f'{ROOT}/data/event-companion-base-sizes.json'
Y = 2.5

# A faction heading is shouted and stands alone above the table.
FACTION = re.compile(r"^[A-Z][A-Z’' ]{3,40}$")
SIZE = re.compile(r'^(?:\d+(?:\.\d+)?\s*(?:x\s*\d+(?:\.\d+)?\s*)?mm|Hull|'
                  r'N/A|Oval.*|.*mm.*)$', re.I)


def main():
    cache = sys.argv[sys.argv.index('--cache') + 1] \
        if '--cache' in sys.argv else None
    if not cache:
        sys.exit('usage: parse-base-sizes.py --cache <dir>')

    raw = json.load(open(os.path.join(cache, '_event-companion.json')))
    doc = pdf_columns.lay_out_pages(raw)

    out, faction = {}, None
    for page in doc:
        text = ' '.join(l['text'] for c in page['columns'] for l in c['lines'])
        if 'BASE SIZE' not in text:
            continue

        # Every line on the page with its position, so the name column and the
        # size column are paired by baseline rather than by order.
        cells = sorted((l['y'], l['x'], l['text'].strip())
                       for c in page['columns'] for l in c['lines']
                       if l['text'].strip())
        heading = next((t for _, _, t in cells[:3] if FACTION.match(t)), None)
        if heading and heading not in ('UNIT', 'BASE SIZE'):
            faction = heading
        if faction is None:
            continue
        rows = out.setdefault(faction, [])

        sizes = [(y, x, t) for y, x, t in cells if SIZE.match(t)]
        for y, x, size in sizes:
            names = [t for ny, nx, t in cells
                     if abs(ny - y) <= Y and nx < x and not SIZE.match(t)]
            if not names:
                continue
            name = ' '.join(names).strip()
            if name.upper() in ('UNIT', 'BASE SIZE') or len(name) < 2:
                continue
            rows.append({'name': name, 'base': size})

    with open(OUT, 'w') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write('\n')
    total = sum(len(v) for v in out.values())
    for k, v in sorted(out.items()):
        print(f'{k:26} {len(v):4}')
    print(f'\n{total} base sizes across {len(out)} factions -> {OUT}')


if __name__ == '__main__':
    main()
