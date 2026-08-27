"""Download each Faction Pack, pull its stratagems out, throw the PDF away.

Two facts about the layout drive this. Pages are laid out in columns whose
number and width change from page to page, so the columns are detected rather
than assumed (see columns.py). And a stratagem always names itself the same
way, whatever the grid:

    SHIELD OF DENIAL
    CHAMPIONS OF FAITH – BATTLE TACTIC STRATAGEM

so the detachment is read off the line under the name and never inferred from
the page header.

Only the WHEN/TARGET/EFFECT/RESTRICTIONS block is kept. The fluff paragraph
above it says nothing about how the stratagem works.
"""
import json, os, re, subprocess, sys

import pdf_columns as columns

STRAT = re.compile(r'^(?P<det>.+?)\s+STRATAGEM$')
FIELD = re.compile(r'^(WHEN|TARGET|EFFECT|RESTRICTIONS):\s*(.*)$')
# A name is shouted; a sentence is not. Guards against a body line that
# happens to precede a wrapped `... STRATAGEM` continuation.
NAME = re.compile(r'^[^a-z]{2,}$')


def column_of(badge, cols):
    """The column a cost badge belongs to.

    The badge is set outside its column's text — left of it in the reprinted
    codex layout, right of it on a new detachment's own page — so a plain
    nearest-column rule gives it to whichever column it happens to sit closer
    to, which on a two-column reprint is the wrong one every time.

    Inside a column's own x-range wins outright. Otherwise the column it sits
    *before* wins, because that is the one it is labelling.
    """
    inside = [c for c in cols if c['xMin'] <= badge['x'] <= c['xMax']]
    if len(inside) == 1:
        return inside[0]

    after = [c for c in cols if c['xMin'] > badge['x']]
    if after:
        col = min(after, key=lambda c: c['xMin'] - badge['x'])
        if col['xMin'] - badge['x'] <= 40:
            return col

    before = [c for c in cols if c['xMax'] < badge['x']]
    if before:
        col = min(before, key=lambda c: badge['x'] - c['xMax'])
        if badge['x'] - col['xMax'] <= 40:
            return col
    return inside[0] if inside else None


def cost_for(name_y, badges):
    """The cost printed against the stratagem whose name is at `name_y`.

    The badge is set alongside the block rather than on the name's own line:
    a couple of points above it on a new detachment's page, and forty to
    seventy-five below it in the reprinted layout, where it is centred on the
    block instead. So it belongs to the nearest name **at or above** it, with
    a little slack for the first case.
    """
    best, cp = None, None
    for badge in badges:
        offset = badge['y'] - name_y
        if offset < -6:
            continue
        if best is None or offset < best:
            best, cp = offset, badge['cp']
    return cp


def stratagems(doc):
    out = []
    for page in doc:
        cols = page['columns']
        owned = {id(c): [] for c in cols}
        for badge in page['badges']:
            col = column_of(badge, cols)
            if col is not None:
                owned[id(col)].append(badge)

        for col in cols:
            lines = col['lines']
            for i, line in enumerate(lines):
                if i == 0:
                    continue
                m = STRAT.match(line['text'].strip())
                if not m:
                    continue
                name = lines[i - 1]['text'].strip()
                if not NAME.match(name):
                    continue
                det = m.group('det').strip()
                kind = None
                if '–' in det:
                    det, kind = (p.strip() for p in det.split('–', 1))
                out.append({
                    'name': name,
                    'cp': cost_for(lines[i - 1]['y'], owned[id(col)]),
                    'detachment': det, 'type': kind,
                    'page': page['page'], 'text': body(lines, i + 1),
                })
    return out


def body(col, start):
    """The WHEN/TARGET/EFFECT block, as the `**WHEN:** …` shape the app uses.

    Stops at the next stratagem's name so a column holding three of them does
    not run them together.
    """
    parts, key, buf = [], None, []

    def flush():
        if key and buf:
            parts.append(f'**{key}:** ' + ' '.join(buf).strip())

    for j in range(start, len(col)):
        line = col[j]['text'].strip()
        if key and j + 1 < len(col) and STRAT.match(col[j + 1]['text'].strip()):
            break
        m = FIELD.match(line)
        if m:
            flush()
            key, buf = m.group(1), [m.group(2)]
        elif key and line:
            buf.append(line)
    flush()
    return '\n\n'.join(parts)


DOTS = '\x08\ufffd.\u2500\u2014\u2013'
SECTIONS = ('datasheets', 'rules updates', 'legends datasheets',
            'imperial armour datasheets', 'faqs')


def detachments(rows):
    """The detachments a pack covers, read off its own contents page.

    From the contents rather than from the stratagem headers, because a
    detachment can have none at all — Sanctified Orators and Librarius
    Conclave each have a rule and some enhancements and nothing else, checked
    against the rendered pages. Without them here, the app's records for those
    detachments would look like no pack covered them.

    `rows` must already be narrowed to the contents column (see
    `contents_rows`): every entry is `<name><leader dots><page>`, and the
    leader dots are what identify one.
    """
    out, inside = [], False
    for row in rows:
        m = re.match(r'^(.+?)[' + DOTS + r']{3,}\s*(\d+)?\s*$', row.strip())
        if not m:
            continue
        name = m.group(1).strip()
        if name.lower() == 'detachments':
            inside = True
        elif name.lower() in SECTIONS:
            inside = False
        elif inside and m.group(2):
            out.append({'name': name, 'page': int(m.group(2))})
    return out


def contents_rows(page):
    """The contents column of a pack's first page, as one row per entry."""
    at = columns.word_x(page, 'CONTENTS')
    return columns.rows_right_of(page, at) if at is not None \
        else columns.page_lines(page)


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKS = f'{ROOT}/data/faction-packs.json'
DETS = f'{ROOT}/data/faction-pack-detachments.json'


def listing():
    at = f'{os.path.dirname(os.path.abspath(__file__))}/faction-packs.tsv'
    for line in open(at):
        line = line.strip()
        if line and not line.startswith('#'):
            yield line.split('\t')


def document(name, url, cache):
    """The pack's laid-out text, downloaded once.

    Cached because the packs carry several sections the app wants and they
    are read by separate passes — stratagems, then the rules updates, then
    whatever the next one needs. Re-downloading a quarter of a gigabyte of
    PDF for each pass is the only alternative.

    What is cached is the **raw extraction**, not the columns: where the
    columns are is a judgement the detector makes, and it has been corrected
    twice. Caching the judgement would mean re-downloading every pack to fix
    it a third time.
    """
    at = os.path.join(cache, f'{name}.json') if cache else None
    if at and os.path.exists(at):
        raw = json.load(open(at))
    else:
        subprocess.run(['curl', '-sSL', '-o', 'work.pdf', url], check=True)
        raw = columns.word_pages('work.pdf')
        os.remove('work.pdf')
        if at:
            os.makedirs(cache, exist_ok=True)
            with open(at, 'w') as f:
                json.dump(raw, f, ensure_ascii=False)
    return columns.lay_out_pages(raw), contents_rows(raw[0]) if raw else []


def main():
    cache = None
    args = sys.argv[1:]
    if '--cache' in args:
        cache = args[args.index('--cache') + 1]
    packs = json.load(open(PACKS)) if os.path.exists(PACKS) else {}
    dets = json.load(open(DETS)) if os.path.exists(DETS) else {}

    for name, url in listing():
        # A leading underscore is a document that is not a faction pack —
        # the Universal Rules Updates, the event companions. They are still
        # cached, because other passes read them.
        cached = cache and os.path.exists(os.path.join(cache, f'{name}.json'))
        if name in packs and (cached or not cache):
            continue
        doc, rows = document(name, url, cache)
        if name.startswith('_'):
            print(f'{name:24} cached, not a faction pack', flush=True)
            continue
        packs[name] = stratagems(doc)
        dets[name] = detachments(rows)
        print(f'{name:24} {len(packs[name]):4} stratagems  '
              f'{len(dets[name]):2} detachments', flush=True)
        for path, data in ((PACKS, packs), (DETS, dets)):
            with open(path, 'w') as f:
                json.dump(data, f, indent=1, ensure_ascii=False)
                f.write('\n')


if __name__ == '__main__':
    main()
