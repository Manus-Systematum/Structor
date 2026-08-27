#!/usr/bin/env python3
"""Datasheets out of the Faction Packs.

A datasheet is two pages. The first carries the name, the statline, the weapon
tables and the abilities; the second carries the fluff, the wargear options,
the unit composition and the loadout sentences. Both end with the same
`KEYWORDS:` / `FACTION KEYWORDS:` footer, which is what identifies the pair.

The stat tables are the reason this is tractable. Each column of the table is
a column on the page, and each is **labelled** — `RANGE`, `A`, `BS`, `S`,
`AP`, `D` — on the same baseline as the `RANGED WEAPONS` header. So the
columns are read off their own headers rather than measured, and a weapon is
whatever sits on one baseline across them. A name that wraps onto a second
line has no stats beside it, which is how the wrap is recognised.

Three sections use the same layout and are all read: `Datasheets`,
`Imperial Armour Datasheets` and `Legends Datasheets`. Which one a datasheet
came from is kept, because the app already distinguishes Legends and needs to
know that Imperial Armour is Forge World's.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pdf_columns  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = f'{ROOT}/data/faction-pack-datasheets.json'

SECTIONS = {
    'datasheets': 'codex',
    'imperial armour datasheets': 'imperial-armour',
    'legends datasheets': 'legends',
}
DOTS = '\x08�.─—–'

PROFILE_HEADS = ('M', 'T', 'SV', 'W', 'LD', 'OC')
WEAPON_HEADS = ('RANGE', 'A', 'BS', 'WS', 'S', 'AP', 'D')
Y = 2.5  # points; lines this close share a baseline


def contents(raw):
    """`[(name, page)]` from the pack's contents page."""
    at = pdf_columns.word_x(raw[0], 'CONTENTS')
    rows = pdf_columns.rows_right_of(raw[0], at) if at is not None \
        else pdf_columns.page_lines(raw[0])
    out = []
    for row in rows:
        m = re.match(r'^(.+?)[' + DOTS + r']{3,}\s*(\d+)?\s*$', row.strip())
        if m and m.group(2):
            out.append((m.group(1).strip(), int(m.group(2))))
    return out


# Every heading that can end a section. A datasheet section runs to the next
# *top-level* heading — not to the next contents entry, which is one of its
# own datasheets and would end the section after its first page.
TOP_LEVEL = set(SECTIONS) | {'detachments', 'rules updates', 'faqs',
                             'forge world datasheets'}


def sections_of(raw):
    """`{page: kind}` for every page inside a datasheet section."""
    listed = contents(raw)
    tops = sorted({page for name, page in listed
                   if name.lower() in TOP_LEVEL})
    out = {}
    for name, page in listed:
        kind = SECTIONS.get(name.lower())
        if not kind:
            continue
        after = [p for p in tops if p > page]
        end = (min(after) - 1) if after else len(raw)
        out.update({p: kind for p in range(page, end + 1)})
    return out


def cells(page):
    """`[(y, x, text)]` for every line on the page, columns flattened."""
    out = []
    for col in page['columns']:
        for line in col['lines']:
            out.append((line['y'], line['x'], line['text'].strip()))
    return sorted(out)


def band(rows, y):
    """Every cell on one baseline, left to right."""
    return [r for r in rows if abs(r[0] - y) <= Y]


def label_columns(rows, y):
    """`{header: x}` for a stat table, read off the header row itself."""
    return {text.upper(): x for _, x, text in band(rows, y)
            if text.upper() in WEAPON_HEADS}


def weapon_rows(rows, start_y, stop_y, columns):
    """The weapons between two headers, each as `(name, {stat: value})`.

    A row exists where the stat columns have values. The name is whatever sits
    left of them on that baseline, plus any line below it that has no stats of
    its own — that is a wrapped name, not a new weapon.
    """
    left = min(columns.values())
    out = []
    seen = set()
    for y, x, text in rows:
        if not (start_y + Y < y < stop_y - Y) or x >= left - 4:
            continue
        stats = {}
        for head, at in columns.items():
            for _, cx, cell in band(rows, y):
                if abs(cx - at) <= 14 and cell:
                    stats[head] = cell
                    break
        if len(stats) >= 4:
            out.append([text, stats, y])
            seen.add(round(y))
        elif out and round(y) not in seen:
            out[-1][0] += ' ' + text
    return [(name, stats) for name, stats, _ in out]


def weapon_rows_inline(rows, start_y, stop_y):
    """Weapons from a table whose stat columns were not separated.

    On a narrow table the gutters between `RANGE A WS S AP D` are too small
    to detect, so the header arrives as one or two cells — `RANGE A WS`,
    `S AP D ABILITIES` — and the values likewise. The header still names the
    columns, in order, so the values are matched to it by position and cut at
    the point the abilities text begins.
    """
    heads = []
    for _, _, text in band(rows, start_y):
        for token in text.split():
            if token.upper() in WEAPON_HEADS:
                heads.append(token.upper())
            elif heads:
                break
    if len(heads) < 3:
        return []

    left = min((x for _, x, t in band(rows, start_y)
                if t.split() and t.split()[0].upper() in WEAPON_HEADS),
               default=None)
    if left is None:
        return []

    out = []
    for y in sorted({r[0] for r in rows if start_y + Y < r[0] < stop_y - Y}):
        line = band(rows, y)
        name = ' '.join(t for _, x, t in line if x < left - 4)
        values = [tok for _, x, t in line if x >= left - 4 for tok in t.split()]
        if not name or len(values) < len(heads):
            continue
        out.append((name.strip(), dict(zip(heads, values[:len(heads)]))))
    return out


def parse_page(page):
    """One datasheet's stat page, or None if this is not one."""
    rows = cells(page)
    if not rows:
        return None

    heads = {}
    for y, x, text in rows:
        upper = text.upper()
        if upper in ('RANGED WEAPONS', 'MELEE WEAPONS', 'ABILITIES',
                     'WARGEAR ABILITIES', 'INVULNERABLE SAVE'):
            heads.setdefault(upper, (y, x))

    if 'RANGED WEAPONS' not in heads and 'MELEE WEAPONS' not in heads:
        return None

    name = rows[0][2]
    if not name or len(name) > 70:
        return None

    # The statline: a header row of M/T/SV/W/LD, with OC in the next column,
    # and its values on the baseline below.
    profile = {}
    for y, _, text in rows:
        parts = text.upper().split()
        if parts and all(p in PROFILE_HEADS for p in parts) and len(parts) >= 3:
            labels = [p for _, _, t in band(rows, y) for p in t.upper().split()]
            below = sorted({r[0] for r in rows if y + Y < r[0] < y + 22})
            if not below:
                break
            values = [v for _, _, t in band(rows, below[0]) for v in t.split()]
            if len(values) >= len(labels):
                candidate = dict(zip(labels, values))
                # A statline whose Toughness is a word, or whose Wounds is
                # not a number, is a misread row — a datasheet with two model
                # profiles stacks them and the labels no longer line up. Kept
                # empty rather than shipped wrong.
                if re.fullmatch(r'\d+', str(candidate.get('T', ''))) and \
                        re.fullmatch(r'\d+', str(candidate.get('W', ''))):
                    profile = candidate
            break

    tables = {}
    for kind in ('RANGED WEAPONS', 'MELEE WEAPONS'):
        if kind not in heads:
            continue
        y = heads[kind][0]
        columns = label_columns(rows, y)
        if len(columns) < 3:
            after = [heads[k][0] for k in heads if heads[k][0] > y + Y]
            found = weapon_rows_inline(rows, y,
                                       min(after) if after else 10_000)
            if found:
                tables[kind.split()[0].lower()] = found
            continue
        after = [heads[k][0] for k in heads if heads[k][0] > y + Y]
        stop = min(after) if after else 10_000
        tables[kind.split()[0].lower()] = weapon_rows(rows, y, stop, columns)

    text_blocks = {}
    for kind in ('ABILITIES', 'WARGEAR ABILITIES'):
        if kind not in heads:
            continue
        y, x = heads[kind]
        # The block is whatever shares the header's column, which on a
        # datasheet is the widest one on the right. An x-tolerance instead
        # picked up the stat columns and read `-4 D6` as an ability.
        column = next((c for c in page['columns']
                       if c['xMin'] - 4 <= x <= c['xMax']), None)
        if column is None:
            continue
        lines = []
        for line in sorted(column['lines'], key=lambda l: l['y']):
            if line['y'] <= y + Y:
                continue
            text_line = line['text'].strip()
            if text_line.upper() in ('WARGEAR ABILITIES',) \
                    or text_line.startswith('FACTION KEYWORDS'):
                break
            if text_line:
                lines.append(text_line)
        text_blocks[kind.lower()] = lines

    faction_at = next((x for _, x, t in rows
                       if t.startswith('FACTION KEYWORDS')), None)

    def footer(marker, right):
        """The keyword list under a footer label.

        The footer runs the width of the page: `KEYWORDS:` on the left and
        `FACTION KEYWORDS:` on the right, each wrapping across whatever
        columns the detector found. So the split between them is the x of the
        faction label, not the column boundaries — reading either from one
        column lost half its keywords, and reading both by baseline welded the
        last of one to the first of the other.
        """
        found = next(((y, x) for y, x, t in rows if t.startswith(marker)), None)
        if found is None:
            return []
        y = found[0]
        picked = [(ry, rx, t) for ry, rx, t in rows if ry >= y - Y and t
                  and (rx >= faction_at - 4 if right
                       else faction_at is None or rx < faction_at - 4)]
        joined = ' '.join(t for _, _, t in sorted(picked))
        joined = joined.split(marker, 1)[1] if marker in joined else joined
        return [k for k in (re.sub(r'[\x00-\x1f]', '', part).strip()
                            for part in joined.split(',')) if k]

    keywords = footer('KEYWORDS:', right=False)
    faction_keywords = footer('FACTION KEYWORDS:', right=True)

    return {
        'name': name,
        'profile': profile,
        'weapons': tables,
        'abilities': text_blocks.get('abilities', []),
        'wargear_abilities': text_blocks.get('wargear abilities', []),
        'keywords': [k for k in keywords if k],
        'faction_keywords': [k for k in faction_keywords if k],
    }


def parse_detail(raw_page):
    """The second page: composition, wargear options and loadout."""
    rows = pdf_columns.page_lines(raw_page)
    out = {'composition': [], 'wargear_options': [], 'loadout': []}
    where = None
    for row in rows:
        upper = row.upper()
        if 'UNIT COMPOSITION' in upper or 'WARGEAR OPTIONS' in upper:
            where = 'both'
            continue
        if row.startswith('KEYWORDS:'):
            break
        if where and row.strip():
            (out['loadout'] if 'equipped with' in row
             else out['composition']).append(row.strip())
    return out


def main():
    cache = sys.argv[sys.argv.index('--cache') + 1] \
        if '--cache' in sys.argv else None
    if not cache:
        sys.exit('usage: parse-datasheets.py --cache <dir> [pack ...]')
    only = [a for a in sys.argv[1:] if not a.startswith('--')
            and a != cache]

    out = {}
    for name in sorted(os.listdir(cache)):
        if not name.endswith('.json'):
            continue
        pack = name[:-5]
        if pack.startswith('_') or (only and pack not in only):
            continue
        raw = json.load(open(os.path.join(cache, name)))
        kinds = sections_of(raw)
        if not kinds:
            continue
        doc = pdf_columns.lay_out_pages(raw)
        by_page = {p['page']: p for p in doc}
        raw_by_page = {p['page']: p for p in raw}

        found = []
        for page, kind in sorted(kinds.items()):
            if page not in by_page:
                continue
            sheet = parse_page(by_page[page])
            if not sheet:
                continue
            sheet['kind'] = kind
            sheet['page'] = page
            if page + 1 in raw_by_page:
                sheet.update(parse_detail(raw_by_page[page + 1]))
            found.append(sheet)
        if found:
            out[pack] = found
            by_kind = {}
            for s in found:
                by_kind[s['kind']] = by_kind.get(s['kind'], 0) + 1
            print(f'{pack:24} {len(found):3} datasheets  {by_kind}', flush=True)

    with open(OUT, 'w') as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write('\n')
    print(f'\n{sum(len(v) for v in out.values())} datasheets -> {OUT}')


if __name__ == '__main__':
    main()
